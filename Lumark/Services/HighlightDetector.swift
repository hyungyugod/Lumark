//
//  HighlightDetector.swift
//  Lumark
//
//  spec §5 step 2 — 페이지 이미지에서 형광펜 영역을 색별로 검출.
//
//  알고리즘 (v0.1):
//    1. 입력 UIImage를 작업용 해상도(기본 1200px 변)로 다운샘플
//    2. RGBA8 픽셀 버퍼로 변환
//    3. 활성 ColorRule마다 HSV 마스크 생성
//    4. 4-이웃 BFS로 연결요소(blob) 라벨링
//    5. 최소 면적 미만 제거 → 노이즈 컷
//    6. blob의 bbox를 padding 후 원본 좌표로 역매핑
//    7. y → x 순으로 정렬 (위→아래, 같은 줄에선 왼→오른쪽)
//
//  Day 2~4 S1 합격선 (spec §7): 정밀도 ≥ 95%, 재현율 ≥ 90%.
//  HSV 범위는 ColorRule.hsvRange에서 주입 — 캘리브레이션 UI 도입(v0.2) 시 재사용.
//

import Foundation
import UIKit

/// 검출 결과 — 단일 형광펜 영역.
/// `boundingBox`는 입력 UIImage의 픽셀 좌표(좌상단 원점, y가 아래로 증가).
struct DetectedRegion: Sendable, Equatable {
    let color: ColorCategory
    let boundingBox: CGRect
    /// 작업 해상도 기준 픽셀 개수. 같은 색 내 정렬·필터링에 사용.
    let area: Int
}

/// 검출 옵션. nonisolated init으로 백그라운드에서도 자유롭게 생성.
struct HighlightDetectorOptions: Sendable {
    /// 작업용 해상도. 긴 변 기준. 너무 크면 느려지고, 너무 작으면 얇은 형광펜이 사라짐.
    var workingDimension: CGFloat = 1200
    /// 작업 해상도 픽셀 수 대비 최소 blob 면적 (노이즈 컷).
    /// 1.0e-4 = 1200x1600 이미지에선 약 190px (대략 14x14 정도).
    /// 얇은 underline 형태 highlight도 잡히도록 보수적으로 낮춘 값.
    var minRegionRatio: Double = 0.00010
    /// bbox 패딩 — OCR에 더 넉넉히 자르기 위한 여유. 작업 해상도 짧은 변의 비율.
    var paddingRatio: Double = 0.012
    /// Morphological closing 반복 수. 형광펜 위에 인쇄된 텍스트 글리프는 HSV
    /// 범위 밖이라 마스크에 구멍을 만들어 한 highlight를 여러 blob으로 쪼갠다.
    /// dilate K번 → erode K번으로 ~2K픽셀까지의 글자 stroke를 메운다.
    /// 0이면 closing 끄기.
    var closingRadius: Int = 2
    /// 세로로 인접한 같은 색 blob 병합 ON/OFF. 한 형광펜 stroke가 여러 줄로
    /// wrap된 경우 단일 영역으로 묶기 위함. 끄면 줄마다 별도 Highlight가 됨.
    var mergeWrappedLines: Bool = true

    nonisolated init(
        workingDimension: CGFloat = 1200,
        minRegionRatio: Double = 0.00010,
        paddingRatio: Double = 0.012,
        closingRadius: Int = 2,
        mergeWrappedLines: Bool = true
    ) {
        self.workingDimension = workingDimension
        self.minRegionRatio = minRegionRatio
        self.paddingRatio = paddingRatio
        self.closingRadius = closingRadius
        self.mergeWrappedLines = mergeWrappedLines
    }
}

nonisolated enum HighlightDetector {

    /// 페이지 이미지에서 활성 색의 형광펜 영역을 검출.
    /// - parameters:
    ///   - image: PageRenderer가 만든 단일 페이지 UIImage
    ///   - rules: 사용자의 ColorRule 목록. `isEnabled == false`이거나
    ///            `ColorCategory.activeInV01`에 없는 색은 무시.
    /// - returns: 위에서 아래로 정렬된 검출 영역들.
    static func detect(
        in image: UIImage,
        rules: [ColorRule],
        options: HighlightDetectorOptions = HighlightDetectorOptions()
    ) -> [DetectedRegion] {
        let activeRules = rules.filter {
            $0.isEnabled && ColorCategory.activeInV01.contains($0.color)
        }
        guard !activeRules.isEmpty, let cgIn = image.cgImage else { return [] }

        // 1. 작업 해상도로 다운샘플 + RGBA8 픽셀 버퍼 추출
        let (pixels, w, h, scaleBackX, scaleBackY) = downsampleRGBA(
            cgIn,
            targetMax: options.workingDimension
        )
        guard w > 0, h > 0, !pixels.isEmpty else { return [] }

        let minArea = max(20, Int(Double(w * h) * options.minRegionRatio))
        let padding = Int(Double(min(w, h)) * options.paddingRatio)

        var regions: [DetectedRegion] = []

        // 2. 활성 색마다 마스크 → closing → 연결요소 → wrap 병합 → bbox
        for rule in activeRules {
            var mask = buildMask(pixels: pixels, w: w, h: h, range: rule.hsvRange)
            if options.closingRadius > 0 {
                morphologicalClose(&mask, w: w, h: h, radius: options.closingRadius)
            }
            let rawBlobs = connectedComponents(mask: mask, w: w, h: h, minArea: minArea)
            // 같은 줄에서 단어 간격 때문에 쪼개진 blob 먼저 합친 뒤,
            // 줄을 가로지르는 wrap을 합친다. 순서 중요 — 가로 먼저 합쳐야
            // wrap 판정에 쓰는 "한 줄짜리 blob의 우측 끝/좌측 끝"이 의미를 가짐.
            let blobs: [Blob] = {
                guard options.mergeWrappedLines else { return rawBlobs }
                let hMerged = mergeHorizontallyAdjacent(rawBlobs, imageWidth: w, imageHeight: h)
                return mergeVerticallyAdjacent(hMerged, imageWidth: w)
            }()

            for blob in blobs {
                // underline 형태 (얇고 긴 가로 띠) → 위쪽 padding만 4배로 늘려
                // 텍스트 본체(underline 위에 있음)까지 OCR bbox에 포함시킨다.
                // 아래쪽은 일반 padding 유지 — 4배로 하면 다음 줄까지 빨려 들어가
                // 다음 줄 텍스트가 함께 OCR되어 의미가 섞임 (asymmetric padding).
                let bh = blob.maxY - blob.minY + 1
                let bw = blob.maxX - blob.minX + 1
                let isUnderlineShape = bh <= 12 && bw >= bh * 5
                let topPad    = isUnderlineShape ? padding * 4 : padding
                let bottomPad = padding

                let padded = CGRect(
                    x: CGFloat(blob.minX - padding),
                    y: CGFloat(blob.minY - topPad),
                    width: CGFloat(bw + padding * 2),
                    height: CGFloat(bh + topPad + bottomPad)
                )
                let clamped = padded.intersection(CGRect(x: 0, y: 0, width: w, height: h))
                guard !clamped.isNull, !clamped.isEmpty else { continue }

                // 작업 → 원본 좌표
                let original = CGRect(
                    x: clamped.minX * scaleBackX,
                    y: clamped.minY * scaleBackY,
                    width: clamped.width * scaleBackX,
                    height: clamped.height * scaleBackY
                )

                regions.append(DetectedRegion(
                    color: rule.color,
                    boundingBox: original.integral,
                    area: blob.area
                ))
            }
        }

        // 3. 위에서 아래로 (같은 줄이면 왼쪽부터)
        return regions.sorted { lhs, rhs in
            let lhsRowKey = lineKey(lhs.boundingBox, imageHeight: CGFloat(h) * scaleBackY)
            let rhsRowKey = lineKey(rhs.boundingBox, imageHeight: CGFloat(h) * scaleBackY)
            if lhsRowKey != rhsRowKey { return lhsRowKey < rhsRowKey }
            return lhs.boundingBox.minX < rhs.boundingBox.minX
        }
    }

    // MARK: - 다운샘플 + RGBA 추출

    /// CGImage를 RGBA8 픽셀 버퍼로 변환. 긴 변이 targetMax 이하가 되도록 다운샘플.
    /// returns: (pixels, width, height, 원본 X 배율, 원본 Y 배율)
    private static func downsampleRGBA(
        _ image: CGImage,
        targetMax: CGFloat
    ) -> (pixels: [UInt8], w: Int, h: Int, scaleBackX: CGFloat, scaleBackY: CGFloat) {
        let srcW = CGFloat(image.width)
        let srcH = CGFloat(image.height)
        let longSide = max(srcW, srcH)
        let scale = longSide > targetMax ? targetMax / longSide : 1.0
        let w = max(1, Int(srcW * scale))
        let h = max(1, Int(srcH * scale))

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = w * 4
        var pixels = [UInt8](repeating: 0, count: w * h * 4)

        guard let ctx = CGContext(
            data: &pixels,
            width: w, height: h,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return ([], 0, 0, 1, 1)
        }

        ctx.interpolationQuality = .medium
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

        let scaleBackX = srcW / CGFloat(w)
        let scaleBackY = srcH / CGFloat(h)
        return (pixels, w, h, scaleBackX, scaleBackY)
    }

    // MARK: - HSV 마스크

    /// RGBA 픽셀 버퍼 → 색 범위에 들어가는 픽셀만 1로 마킹한 1바이트 마스크.
    private static func buildMask(
        pixels: [UInt8],
        w: Int,
        h: Int,
        range: HSVRange
    ) -> [UInt8] {
        var mask = [UInt8](repeating: 0, count: w * h)
        // hue 범위는 spec 상 항상 0..360 직선 구간. (분홍은 320..360처럼 끝쪽이지만 wrap 안 함.)
        // 만약 hMin > hMax면 wrap 처리. 안전망.
        let wrap = range.hMin > range.hMax

        pixels.withUnsafeBufferPointer { buf in
            mask.withUnsafeMutableBufferPointer { mbuf in
                var idx = 0
                for i in 0..<(w * h) {
                    let r = Double(buf[idx]) / 255.0
                    let g = Double(buf[idx + 1]) / 255.0
                    let b = Double(buf[idx + 2]) / 255.0
                    idx += 4

                    let maxC = max(r, max(g, b))
                    let minC = min(r, min(g, b))
                    let v = maxC
                    let delta = maxC - minC

                    // 채도·명도 컷 — 형광펜은 항상 채도 높고 밝음.
                    if v < range.vMin { continue }
                    let s = maxC == 0 ? 0 : delta / maxC
                    if s < range.sMin { continue }

                    // hue
                    var hDeg: Double
                    if delta == 0 {
                        hDeg = 0
                    } else if maxC == r {
                        hDeg = 60 * ((g - b) / delta)
                    } else if maxC == g {
                        hDeg = 60 * ((b - r) / delta + 2)
                    } else {
                        hDeg = 60 * ((r - g) / delta + 4)
                    }
                    if hDeg < 0 { hDeg += 360 }

                    let inRange: Bool
                    if wrap {
                        inRange = hDeg >= range.hMin || hDeg <= range.hMax
                    } else {
                        inRange = hDeg >= range.hMin && hDeg <= range.hMax
                    }
                    if inRange {
                        mbuf[i] = 1
                    }
                }
            }
        }

        return mask
    }

    // MARK: - Morphological closing (separable sliding window)

    /// dilate(R) → erode(R). (2R+1)×(2R+1) square structuring element.
    /// 텍스트 stroke가 만든 ~2R픽셀 폭 구멍을 메운다. 인접한 두 highlight가
    /// 2R픽셀 미만으로 떨어져 있으면 합쳐질 수 있으니 radius는 작게 유지.
    /// 분리 가능 구현이라 O(w*h) per pass — 18s → <1s 차이.
    private static func morphologicalClose(_ mask: inout [UInt8], w: Int, h: Int, radius: Int) {
        guard radius > 0 else { return }
        dilateSeparable(&mask, w: w, h: h, radius: radius)
        erodeSeparable(&mask, w: w, h: h, radius: radius)
    }

    /// 슬라이딩 윈도우 dilate. 각 픽셀: [x-r, x+r] 안에 켜진 픽셀이 있으면 1.
    private static func dilateSeparable(_ mask: inout [UInt8], w: Int, h: Int, radius: Int) {
        slidingWindow(&mask, w: w, h: h, radius: radius, threshold: 1)
    }

    /// 슬라이딩 윈도우 erode. 각 픽셀: [x-r, x+r] 안이 모두 켜져 있어야 1.
    private static func erodeSeparable(_ mask: inout [UInt8], w: Int, h: Int, radius: Int) {
        // window size = 2r+1. 모두 켜져 있을 조건 = count == windowSize.
        // 단, 경계에서는 가용 픽셀 수만큼만 따짐.
        slidingWindowMin(&mask, w: w, h: h, radius: radius)
    }

    /// 행 → 열 두 번에 걸쳐 sliding count로 픽셀이 켜진 게 threshold개 이상이면 on.
    /// dilate: threshold=1.
    private static func slidingWindow(_ mask: inout [UInt8], w: Int, h: Int, radius: Int, threshold: Int) {
        var tmp = [UInt8](repeating: 0, count: w * h)
        mask.withUnsafeMutableBufferPointer { mPtr in
            tmp.withUnsafeMutableBufferPointer { tPtr in
                // 행 방향
                for y in 0..<h {
                    let row = y * w
                    var count = 0
                    let limit = min(radius, w - 1)
                    for x in 0...limit { if mPtr[row + x] != 0 { count += 1 } }
                    for x in 0..<w {
                        tPtr[row + x] = count >= threshold ? 1 : 0
                        let addIdx = x + radius + 1
                        if addIdx < w, mPtr[row + addIdx] != 0 { count += 1 }
                        let remIdx = x - radius
                        if remIdx >= 0, mPtr[row + remIdx] != 0 { count -= 1 }
                    }
                }
                // 열 방향 (tmp → mask)
                for x in 0..<w {
                    var count = 0
                    let limit = min(radius, h - 1)
                    for y in 0...limit { if tPtr[y * w + x] != 0 { count += 1 } }
                    for y in 0..<h {
                        mPtr[y * w + x] = count >= threshold ? 1 : 0
                        let addIdx = y + radius + 1
                        if addIdx < h, tPtr[addIdx * w + x] != 0 { count += 1 }
                        let remIdx = y - radius
                        if remIdx >= 0, tPtr[remIdx * w + x] != 0 { count -= 1 }
                    }
                }
            }
        }
    }

    /// erode (sliding window minimum): 윈도우 내 모든 픽셀이 켜져 있어야 1.
    /// count == windowSize (실제 가용 크기)인 경우에만 1.
    private static func slidingWindowMin(_ mask: inout [UInt8], w: Int, h: Int, radius: Int) {
        var tmp = [UInt8](repeating: 0, count: w * h)
        mask.withUnsafeMutableBufferPointer { mPtr in
            tmp.withUnsafeMutableBufferPointer { tPtr in
                // 행 방향
                for y in 0..<h {
                    let row = y * w
                    var count = 0
                    let limit = min(radius, w - 1)
                    for x in 0...limit { if mPtr[row + x] != 0 { count += 1 } }
                    for x in 0..<w {
                        let lo = max(0, x - radius)
                        let hi = min(w - 1, x + radius)
                        let winSize = hi - lo + 1
                        tPtr[row + x] = count == winSize ? 1 : 0
                        let addIdx = x + radius + 1
                        if addIdx < w, mPtr[row + addIdx] != 0 { count += 1 }
                        let remIdx = x - radius
                        if remIdx >= 0, mPtr[row + remIdx] != 0 { count -= 1 }
                    }
                }
                // 열 방향
                for x in 0..<w {
                    var count = 0
                    let limit = min(radius, h - 1)
                    for y in 0...limit { if tPtr[y * w + x] != 0 { count += 1 } }
                    for y in 0..<h {
                        let lo = max(0, y - radius)
                        let hi = min(h - 1, y + radius)
                        let winSize = hi - lo + 1
                        mPtr[y * w + x] = count == winSize ? 1 : 0
                        let addIdx = y + radius + 1
                        if addIdx < h, tPtr[addIdx * w + x] != 0 { count += 1 }
                        let remIdx = y - radius
                        if remIdx >= 0, tPtr[remIdx * w + x] != 0 { count -= 1 }
                    }
                }
            }
        }
    }

    // MARK: - 연결요소 라벨링 (4-이웃 BFS)

    fileprivate struct Blob {
        var minX: Int, minY: Int, maxX: Int, maxY: Int
        var area: Int

        var bbox: CGRect {
            CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        }
    }

    private static func connectedComponents(
        mask: [UInt8],
        w: Int,
        h: Int,
        minArea: Int
    ) -> [Blob] {
        var visited = [Bool](repeating: false, count: w * h)
        var result: [Blob] = []
        // 재사용 가능한 큐 — 매 블롭마다 새로 만들지 않고 reset.
        var queue: [Int] = []
        queue.reserveCapacity(1024)

        for start in 0..<(w * h) {
            if visited[start] || mask[start] == 0 { continue }

            queue.removeAll(keepingCapacity: true)
            queue.append(start)
            visited[start] = true

            let sx = start % w
            let sy = start / w
            var blob = Blob(minX: sx, minY: sy, maxX: sx, maxY: sy, area: 0)

            var head = 0
            while head < queue.count {
                let p = queue[head]; head += 1
                let x = p % w
                let y = p / w
                blob.area += 1
                if x < blob.minX { blob.minX = x }
                if y < blob.minY { blob.minY = y }
                if x > blob.maxX { blob.maxX = x }
                if y > blob.maxY { blob.maxY = y }

                // 4-이웃
                if x > 0 {
                    let n = p - 1
                    if !visited[n] && mask[n] != 0 { visited[n] = true; queue.append(n) }
                }
                if x + 1 < w {
                    let n = p + 1
                    if !visited[n] && mask[n] != 0 { visited[n] = true; queue.append(n) }
                }
                if y > 0 {
                    let n = p - w
                    if !visited[n] && mask[n] != 0 { visited[n] = true; queue.append(n) }
                }
                if y + 1 < h {
                    let n = p + w
                    if !visited[n] && mask[n] != 0 { visited[n] = true; queue.append(n) }
                }
            }

            if blob.area >= minArea {
                result.append(blob)
            }
        }
        return result
    }

    // MARK: - 같은 줄 fragment 병합

    /// 같은 줄에 있지만 단어 띄어쓰기 / 텍스트 descender 때문에 별개 blob으로
    /// 잡힌 같은 색 영역들을 합친다. underline 형 형광펜에서 가장 빈번.
    ///
    /// 알고리즘:
    ///   1. midY 오름차순 정렬 후 greedy 줄 클러스터링
    ///      (다음 blob의 midY가 현재 줄의 최근 midY와 lineBand 이내면 같은 줄)
    ///   2. 각 줄 안에서 x 정렬 → 가로 gap ≤ gapLimit이면 union
    ///
    /// lineBand는 underline 높이(작음)가 아니라 **이미지 높이 기반**으로 잡는다.
    /// 얇은 underline은 줄 안에서 몇 px씩 흔들려서, 높이 비례 임계값으론 같은 줄을
    /// 못 묶었음. 줄 간격(보통 이미지 높이의 ~2% 이상)보단 작아 인접 줄은 안 섞임.
    private static func mergeHorizontallyAdjacent(_ blobs: [Blob], imageWidth: Int, imageHeight: Int) -> [Blob] {
        guard blobs.count > 1 else { return blobs }

        let gapLimit = Int(Double(imageWidth) * 0.06)
        let lineBand = max(8, Int(Double(imageHeight) * 0.011))

        func midY(_ b: Blob) -> Int { (b.minY + b.maxY) / 2 }

        // 1) midY 정렬 후 greedy 줄 클러스터링
        let byY = blobs.sorted { midY($0) < midY($1) }
        var lines: [[Blob]] = []
        var line: [Blob] = [byY[0]]
        var lineMidY = midY(byY[0])
        for b in byY.dropFirst() {
            let m = midY(b)
            if m - lineMidY <= lineBand {
                line.append(b)
                lineMidY = m          // 줄을 따라 완만한 drift 허용
            } else {
                lines.append(line)
                line = [b]
                lineMidY = m
            }
        }
        lines.append(line)

        // 2) 각 줄 안에서 x 정렬 후 gap 병합
        var result: [Blob] = []
        for lineBlobs in lines {
            let sorted = lineBlobs.sorted { $0.minX < $1.minX }
            var current = sorted[0]
            for next in sorted.dropFirst() {
                let xGap = next.minX - current.maxX   // 음수면 겹침
                if xGap <= gapLimit {
                    current = Blob(
                        minX: min(current.minX, next.minX),
                        minY: min(current.minY, next.minY),
                        maxX: max(current.maxX, next.maxX),
                        maxY: max(current.maxY, next.maxY),
                        area: current.area + next.area
                    )
                } else {
                    result.append(current)
                    current = next
                }
            }
            result.append(current)
        }
        return result
    }

    // MARK: - 줄 wrap 병합

    /// 같은 색이지만 페이지 텍스트 줄 사이의 공백 때문에 별개의 blob으로 잡힌 영역들을
    /// 하나로 묶는다. 한 형광펜 stroke가 2~3줄에 걸쳐 그어진 경우, OCR을 한 큰 영역에
    /// 한 번만 돌리고 결과를 단일 Highlight(=마크다운 한 bullet)로 표현하기 위함.
    ///
    /// 병합 조건 (둘 다 만족):
    ///   - 세로 간격 ≤ min(prev.height, next.height) × 1.2 (대략 한 줄 간격 이내)
    ///   - 가로로 연속됨: (a) 가로 겹침이 있거나, (b) prev가 페이지 우측에서 끝나고
    ///                  next가 좌측에서 시작 (자연스러운 줄 wrap)
    ///
    /// 같은 색 두 highlight가 줄 하나를 사이에 두고 떨어져 있으면 세로 간격이 커서
    /// 병합되지 않는다 — 보수적 휴리스틱.
    private static func mergeVerticallyAdjacent(_ blobs: [Blob], imageWidth: Int) -> [Blob] {
        guard blobs.count > 1 else { return blobs }
        let sorted = blobs.sorted {
            ($0.minY, $0.minX) < ($1.minY, $1.minX)
        }
        let rightZone = Int(Double(imageWidth) * 0.60)  // prev.maxX > 0.60 * W = "우측에서 끝남"
        let leftZone  = Int(Double(imageWidth) * 0.40)  // next.minX < 0.40 * W = "좌측에서 시작"

        var result: [Blob] = []
        var current = sorted[0]

        for next in sorted.dropFirst() {
            let curH = current.maxY - current.minY + 1
            let nxtH = next.maxY    - next.minY    + 1
            let minH = min(curH, nxtH)
            let yGap = next.minY - current.maxY   // 음수면 세로로 겹침

            // 1) 세로 인접성
            let verticallyAdjacent = yGap <= (minH * 12) / 10

            // 2) 가로 연속성
            let horizontalOverlap = max(0, min(current.maxX, next.maxX) - max(current.minX, next.minX))
            let isOverlapping = horizontalOverlap > 0
            let isWrap = current.maxX >= rightZone && next.minX <= leftZone
            let horizontallyContinuous = isOverlapping || isWrap

            if verticallyAdjacent && horizontallyContinuous {
                current = Blob(
                    minX: min(current.minX, next.minX),
                    minY: min(current.minY, next.minY),
                    maxX: max(current.maxX, next.maxX),
                    maxY: max(current.maxY, next.maxY),
                    area: current.area + next.area
                )
            } else {
                result.append(current)
                current = next
            }
        }
        result.append(current)
        return result
    }

    // MARK: - 줄(line) 기준 정렬

    /// 같은 텍스트 줄에 있는 영역끼리 같은 키를 갖도록 양자화.
    /// 형광펜은 보통 한 줄에 여러 개 있을 수 있고, y가 살짝씩만 다름.
    private static func lineKey(_ bbox: CGRect, imageHeight: CGFloat) -> Int {
        // 페이지 높이의 1.5% 단위로 양자화 — A4 기준 약 12pt 정도.
        let bin = max(1, imageHeight * 0.015)
        return Int(bbox.midY / bin)
    }
}
