//
//  HighlightDetectorTests.swift
//  LumarkTests
//
//  HighlightDetector는 픽셀 알고리즘이라 외부 자산 없이 합성 이미지로
//  검증 가능. 여기서는 contract 4가지만 잠근다:
//
//    1. 합성 노랑 블롭 1개 → 노랑 1개 검출 + bbox가 합리적인 위치
//    2. 노랑 + 주황 두 블롭 → 색별로 분리해 각각 1개씩
//    3. 흰 페이지 → 0개
//    4. isEnabled=false인 색은 픽셀이 있어도 무시
//    5. 작은 노이즈(min area 미만)는 필터링
//    6. 같은 색 두 블롭은 위→아래 순으로 정렬
//

import Testing
import Foundation
import UIKit
@testable import Lumark

@Suite("HighlightDetector — synthesized image invariants")
struct HighlightDetectorTests {

    // MARK: - 헬퍼

    /// 흰 배경 + 지정 사각형들을 칠한 이미지.
    private func image(
        size: CGSize = CGSize(width: 800, height: 1000),
        rects: [(CGRect, UIColor)]
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            for (rect, color) in rects {
                color.setFill()
                ctx.fill(rect)
            }
        }
    }

    /// 노랑/주황 ColorRule 기본값 — ColorRule.defaults 그대로.
    private var defaultRules: [ColorRule] {
        ColorRule.defaults
    }

    // 형광펜에 가까운 채도 높은 노랑/주황
    private let highlighterYellow = UIColor(red: 1.0, green: 0.92, blue: 0.20, alpha: 1.0)
    private let highlighterOrange = UIColor(red: 1.0, green: 0.55, blue: 0.10, alpha: 1.0)

    // MARK: - Tests

    @Test("노랑 블록 하나 → 노랑 영역 1개")
    func singleYellowBlob() {
        let target = CGRect(x: 200, y: 300, width: 240, height: 50)
        let img = image(rects: [(target, highlighterYellow)])

        let regions = HighlightDetector.detect(in: img, rules: defaultRules)
        let yellow = regions.filter { $0.color == .yellow }

        #expect(yellow.count == 1)
        if let r = yellow.first {
            // bbox는 padding 포함이라 약간 더 클 수 있음 — 원본 사각형과 충분히 겹치는지만 확인
            let intersection = r.boundingBox.intersection(target)
            #expect(!intersection.isNull)
            #expect(intersection.width >= target.width * 0.7)
            #expect(intersection.height >= target.height * 0.7)
        }
    }

    @Test("노랑 + 주황 블록 → 색별로 분리")
    func mixedColors() {
        let yellowRect = CGRect(x: 100, y: 200, width: 300, height: 60)
        let orangeRect = CGRect(x: 100, y: 500, width: 200, height: 70)
        let img = image(rects: [(yellowRect, highlighterYellow), (orangeRect, highlighterOrange)])

        let regions = HighlightDetector.detect(in: img, rules: defaultRules)

        #expect(regions.filter { $0.color == .yellow }.count == 1)
        #expect(regions.filter { $0.color == .orange }.count == 1)
    }

    @Test("흰 페이지는 0개 검출")
    func blankPage() {
        let img = image(rects: [])
        let regions = HighlightDetector.detect(in: img, rules: defaultRules)
        #expect(regions.isEmpty)
    }

    @Test("isEnabled=false인 색은 픽셀이 있어도 무시")
    func disabledColorIgnored() {
        let target = CGRect(x: 200, y: 300, width: 240, height: 50)
        let img = image(rects: [(target, highlighterYellow)])

        // 노랑만 비활성화
        let rules = defaultRules.map { rule -> ColorRule in
            ColorRule(
                id: rule.id,
                color: rule.color,
                label: rule.label,
                isEnabled: rule.color == .yellow ? false : rule.isEnabled,
                hsvRange: rule.hsvRange
            )
        }

        let regions = HighlightDetector.detect(in: img, rules: rules)
        #expect(regions.filter { $0.color == .yellow }.isEmpty)
    }

    @Test("아주 작은 점은 minArea 미만이라 필터링")
    func tinyNoiseFiltered() {
        // 4x4 픽셀 = 16픽셀. 1200px 작업 해상도 기준 minArea(~290) 한참 아래.
        let tiny = CGRect(x: 400, y: 400, width: 4, height: 4)
        let img = image(rects: [(tiny, highlighterYellow)])

        let regions = HighlightDetector.detect(in: img, rules: defaultRules)
        #expect(regions.isEmpty)
    }

    @Test("같은 색 두 블롭은 위에서 아래로 정렬")
    func sortedTopToBottom() {
        let lower = CGRect(x: 100, y: 700, width: 200, height: 50)
        let upper = CGRect(x: 100, y: 100, width: 200, height: 50)
        // 일부러 입력 순서를 거꾸로
        let img = image(rects: [(lower, highlighterYellow), (upper, highlighterYellow)])

        let regions = HighlightDetector.detect(in: img, rules: defaultRules)
        #expect(regions.count == 2)
        if regions.count == 2 {
            #expect(regions[0].boundingBox.midY < regions[1].boundingBox.midY)
        }
    }

    @Test("rules 비어있으면 빈 결과")
    func emptyRules() {
        let target = CGRect(x: 200, y: 300, width: 240, height: 50)
        let img = image(rects: [(target, highlighterYellow)])
        let regions = HighlightDetector.detect(in: img, rules: [])
        #expect(regions.isEmpty)
    }

    // MARK: - 줄 wrap 병합

    @Test("같은 색이 두 줄에 걸쳐 있으면 하나의 영역으로 병합")
    func mergeWrappedSameColor() {
        // 한 형광펜 stroke가 줄을 넘어 이어진 상황:
        //   line1: 페이지 좌측에서 우측 끝까지
        //   line2: 다음 줄의 좌측에서 중간까지 (이어지는 wrap)
        let line1 = CGRect(x: 80, y: 200, width: 620, height: 30)
        let line2 = CGRect(x: 80, y: 240, width: 260, height: 30)
        let img = image(rects: [
            (line1, highlighterYellow),
            (line2, highlighterYellow),
        ])

        let regions = HighlightDetector.detect(in: img, rules: defaultRules)
        let yellow = regions.filter { $0.color == .yellow }
        #expect(yellow.count == 1)
        // 병합된 bbox는 두 영역 모두를 포함해야 함
        if let merged = yellow.first {
            #expect(merged.boundingBox.minY <= line1.minY + 5)
            #expect(merged.boundingBox.maxY >= line2.maxY - 5)
        }
    }

    @Test("세로로 멀리 떨어진 같은 색 두 영역은 병합되지 않음")
    func dontMergeIfVerticallyFar() {
        // 두 줄 사이에 5줄 이상 공백이 있는 경우 — 서로 다른 highlight로 간주
        let upper = CGRect(x: 80, y: 100, width: 300, height: 50)
        let lower = CGRect(x: 80, y: 600, width: 300, height: 50)
        let img = image(rects: [
            (upper, highlighterYellow),
            (lower, highlighterYellow),
        ])
        let regions = HighlightDetector.detect(in: img, rules: defaultRules)
        #expect(regions.filter { $0.color == .yellow }.count == 2)
    }

    @Test("같은 줄에 옆으로 떨어진 두 영역은 병합되지 않음 (각각 별개 형광펜)")
    func dontMergeSideBySide() {
        // 같은 y, 가로로 멀리 떨어져 있고 wrap 패턴도 아님 (좌측 끝나는 곳이 우측 zone 밖)
        let left  = CGRect(x: 80,  y: 200, width: 200, height: 30)
        let right = CGRect(x: 540, y: 200, width: 180, height: 30)
        let img = image(rects: [
            (left, highlighterYellow),
            (right, highlighterYellow),
        ])
        let regions = HighlightDetector.detect(in: img, rules: defaultRules)
        #expect(regions.filter { $0.color == .yellow }.count == 2)
    }

    @Test("mergeWrappedLines=false 옵션이면 인접해도 분리 유지")
    func mergeCanBeDisabled() {
        let line1 = CGRect(x: 80, y: 200, width: 620, height: 30)
        let line2 = CGRect(x: 80, y: 240, width: 260, height: 30)
        let img = image(rects: [
            (line1, highlighterYellow),
            (line2, highlighterYellow),
        ])
        let opts = HighlightDetectorOptions(mergeWrappedLines: false)
        let regions = HighlightDetector.detect(in: img, rules: defaultRules, options: opts)
        #expect(regions.filter { $0.color == .yellow }.count == 2)
    }

    // MARK: - 같은 줄 fragment 병합 (underline 형 highlight)

    @Test("같은 줄의 가로로 가까운 같은 색 fragment는 하나로 병합")
    func mergeFragmentsOnSameLine() {
        // 단어 띄어쓰기 때문에 underline이 3조각으로 쪼개진 상황 시뮬.
        // 각 조각 사이 gap = 20~25px, 이미지폭 800 → 5% = 40px → 병합 조건 충족.
        let f1 = CGRect(x: 80,  y: 500, width: 150, height: 5)
        let f2 = CGRect(x: 250, y: 500, width: 180, height: 5)
        let f3 = CGRect(x: 450, y: 500, width: 130, height: 5)
        let img = image(rects: [
            (f1, highlighterYellow),
            (f2, highlighterYellow),
            (f3, highlighterYellow),
        ])
        let regions = HighlightDetector.detect(in: img, rules: defaultRules)
        let yellow = regions.filter { $0.color == .yellow }
        #expect(yellow.count == 1)
    }

    @Test("미세하게 y가 흔들리는 underline fragment도 같은 줄로 병합")
    func mergeFragmentsWithSlightYWobble() {
        // underline은 줄 안에서 몇 px씩 흔들림 — 높이 비례 임계값으론 못 잡던 케이스.
        // 800x1000 → lineBand = max(8, 11) = 11px. ±4px 흔들림은 같은 줄.
        let f1 = CGRect(x: 80,  y: 500, width: 150, height: 5)   // midY ~502
        let f2 = CGRect(x: 250, y: 504, width: 180, height: 5)   // midY ~506
        let f3 = CGRect(x: 450, y: 498, width: 130, height: 6)   // midY ~501
        let img = image(rects: [
            (f1, highlighterYellow),
            (f2, highlighterYellow),
            (f3, highlighterYellow),
        ])
        let regions = HighlightDetector.detect(in: img, rules: defaultRules)
        #expect(regions.filter { $0.color == .yellow }.count == 1)
    }

    @Test("줄 간격만큼 떨어진 두 underline은 다른 줄로 보존")
    func dontMergeAcrossLines() {
        // 800x1000 → lineBand 11px. 줄 간격 60px면 명확히 다른 줄.
        let line1 = CGRect(x: 80, y: 400, width: 400, height: 5)
        let line2 = CGRect(x: 80, y: 460, width: 400, height: 5)
        let img = image(rects: [
            (line1, highlighterYellow),
            (line2, highlighterYellow),
        ])
        let regions = HighlightDetector.detect(in: img, rules: defaultRules)
        #expect(regions.filter { $0.color == .yellow }.count == 2)
    }

    @Test("같은 줄이라도 멀리 떨어진 fragment는 병합되지 않음")
    func dontMergeIfGapTooLargeSameLine() {
        // gap = 260px, 5% threshold(40px) 한참 초과 → 별개 highlight로 보존
        let f1 = CGRect(x: 80,  y: 500, width: 150, height: 5)
        let f2 = CGRect(x: 490, y: 500, width: 200, height: 5)
        let img = image(rects: [
            (f1, highlighterYellow),
            (f2, highlighterYellow),
        ])
        let regions = HighlightDetector.detect(in: img, rules: defaultRules)
        #expect(regions.filter { $0.color == .yellow }.count == 2)
    }

    // MARK: - underline 형 bbox 세로 padding

    @Test("얇은 underline 형 blob은 세로 padding이 더 크게 확장됨")
    func underlineShapeGetsExtendedVerticalPadding() {
        // 200px 폭 × 4px 높이 — underline 판정 조건 만족 (height ≤ 12, width ≥ 5×height)
        let underline = CGRect(x: 200, y: 500, width: 200, height: 4)
        let img = image(rects: [(underline, highlighterYellow)])

        let regions = HighlightDetector.detect(in: img, rules: defaultRules)
        let yellow = regions.filter { $0.color == .yellow }
        #expect(yellow.count == 1)

        // 일반 padding은 ~9px (800*0.012). underline은 위쪽만 4배(36px), 아래는 일반(9px).
        // 결과 bbox 세로는 원본 4 + 36 + 9 = 49 근처. 충분히 확장됐는지만 확인.
        if let r = yellow.first {
            #expect(r.boundingBox.height >= 40,
                    "underline bbox 세로 padding 미적용? height=\(r.boundingBox.height)")
            // 가로는 보통 padding이라 200 + ~18 = 218 근처
            #expect(r.boundingBox.width <= 250,
                    "underline 가로 padding이 과도? width=\(r.boundingBox.width)")
        }
    }

    @Test("underline bbox padding은 비대칭 — 위로만 4배, 아래로는 일반")
    func underlinePaddingIsAsymmetric() {
        // 아래로도 4배가 적용되면 다음 줄 텍스트가 OCR 영역에 빨려 들어가 의미 섞임.
        // 이 테스트는 위/아래 확장량을 직접 비교한다.
        let originY: CGFloat = 500
        let originHeight: CGFloat = 4
        let underline = CGRect(x: 200, y: originY, width: 200, height: originHeight)
        let img = image(rects: [(underline, highlighterYellow)])

        let regions = HighlightDetector.detect(in: img, rules: defaultRules)
        if let r = regions.first(where: { $0.color == .yellow }) {
            let topExtension    = originY - r.boundingBox.minY
            let bottomExtension = r.boundingBox.maxY - (originY + originHeight)

            // 800px 폭이라 padding 약 9px → underline은 위 4×9 = 36, 아래 9 근처
            #expect(topExtension >= 25,
                    "위쪽 padding 부족 — 텍스트 본체를 못 잡음: \(topExtension)")
            #expect(bottomExtension <= 15,
                    "아래쪽 padding 과다 — 다음 줄 누출 위험: \(bottomExtension)")
            #expect(topExtension > bottomExtension * 2,
                    "padding이 비대칭이 아님: top=\(topExtension), bottom=\(bottomExtension)")
        }
    }

    @Test("일반 형 highlight는 세로/가로 padding 모두 보통")
    func regularShapeGetsNormalPadding() {
        // 240×50 — width(240) < 5×height(250) → underline 아님
        let normal = CGRect(x: 200, y: 300, width: 240, height: 50)
        let img = image(rects: [(normal, highlighterYellow)])
        let regions = HighlightDetector.detect(in: img, rules: defaultRules)
        if let r = regions.first(where: { $0.color == .yellow }) {
            // 세로 padding이 4배로 부풀지 않았는지 — 50 + 4*9*2 = 122는 안 돼야 함
            #expect(r.boundingBox.height <= 80,
                    "일반 highlight에 underline padding 잘못 적용? height=\(r.boundingBox.height)")
        }
    }
}
