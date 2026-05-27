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
    /// 1.5e-4 = 1200x1600 이미지에선 약 290px (대략 17x17 정도).
    var minRegionRatio: Double = 0.00015
    /// bbox 패딩 — OCR에 더 넉넉히 자르기 위한 여유. 작업 해상도 짧은 변의 비율.
    var paddingRatio: Double = 0.012

    nonisolated init(
        workingDimension: CGFloat = 1200,
        minRegionRatio: Double = 0.00015,
        paddingRatio: Double = 0.012
    ) {
        self.workingDimension = workingDimension
        self.minRegionRatio = minRegionRatio
        self.paddingRatio = paddingRatio
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

        // 2. 활성 색마다 마스크 → 연결요소 → bbox
        for rule in activeRules {
            let mask = buildMask(pixels: pixels, w: w, h: h, range: rule.hsvRange)
            let blobs = connectedComponents(mask: mask, w: w, h: h, minArea: minArea)

            for blob in blobs {
                let padded = blob.bbox.insetBy(dx: -CGFloat(padding), dy: -CGFloat(padding))
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

    // MARK: - 줄(line) 기준 정렬

    /// 같은 텍스트 줄에 있는 영역끼리 같은 키를 갖도록 양자화.
    /// 형광펜은 보통 한 줄에 여러 개 있을 수 있고, y가 살짝씩만 다름.
    private static func lineKey(_ bbox: CGRect, imageHeight: CGFloat) -> Int {
        // 페이지 높이의 1.5% 단위로 양자화 — A4 기준 약 12pt 정도.
        let bin = max(1, imageHeight * 0.015)
        return Int(bbox.midY / bin)
    }
}
