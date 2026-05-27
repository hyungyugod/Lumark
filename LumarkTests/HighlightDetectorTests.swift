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
}
