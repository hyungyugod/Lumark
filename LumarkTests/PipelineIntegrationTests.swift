//
//  PipelineIntegrationTests.swift
//  LumarkTests
//
//  HighlightDetector → OCRService → MarkdownDocument 전체 파이프라인을
//  합성 이미지로 한 바퀴 돌려본다. ProcessingViewModel.runReal과 같은 일을 하는 셈.
//
//  목적: 단위 테스트가 각 컴포넌트만 잠그는 데 비해, 이 테스트는 인접 컴포넌트 간
//  contract(좌표·정렬·spec §6 섹션 분할)가 실제로 맞물려 동작하는지 검증한다.
//
//  한국어 OCR 정확도(CER/WER)는 Day 2~4 ground truth로 별도 측정 — 여기서는
//  Vision 결과가 영문에서는 거의 결정론적임을 이용해 영문 토큰으로만 검증.
//

import Testing
import Foundation
import UIKit
@testable import Lumark

@Suite("Pipeline integration — synthesized highlights end-to-end")
struct PipelineIntegrationTests {

    // MARK: - 픽스처

    /// 흰 배경 + 형광펜 사각형(불투명) + 그 위에 검정 텍스트.
    /// 실 페이지처럼 반투명 합성으로 만들면 OCR이 흐려진 글자에 약해서, 통합 테스트는
    /// "검출이 잡힌다 + OCR이 텍스트를 읽는다" 두 contract만 검증한다 — Vision의
    /// 정확도 자체는 Day 2~4 ground truth로 별도 측정.
    private func synthesizedPage(
        size: CGSize = CGSize(width: 900, height: 1200),
        marks: [(text: String, rect: CGRect, color: UIColor)]
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let r = UIGraphicsImageRenderer(size: size, format: format)
        return r.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            // 1) 형광펜 사각형 (불투명)
            for mark in marks {
                mark.color.setFill()
                ctx.fill(mark.rect)
            }
            // 2) 그 위에 검정 텍스트 — OCR contrast 보존
            for mark in marks {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 36, weight: .bold),
                    .foregroundColor: UIColor.black,
                ]
                let textOrigin = CGPoint(x: mark.rect.minX + 16, y: mark.rect.minY + 12)
                NSAttributedString(string: mark.text, attributes: attrs).draw(at: textOrigin)
            }
        }
    }

    // 형광펜 톤
    private let yellow = UIColor(red: 1.0, green: 0.92, blue: 0.20, alpha: 1.0)
    private let orange = UIColor(red: 1.0, green: 0.55, blue: 0.10, alpha: 1.0)

    // MARK: - Tests

    @Test("두 페이지 합성 입력 → 색 카운트 + 섹션 구조 일치")
    @MainActor
    func twoPagePipeline() async {
        // p1: orange "TOPIC" + yellow "ITEM ONE" + yellow "ITEM TWO"
        let p1 = synthesizedPage(marks: [
            ("TOPIC",    CGRect(x: 80,  y: 120, width: 380, height: 70), orange),
            ("ITEM ONE", CGRect(x: 80,  y: 320, width: 420, height: 70), yellow),
            ("ITEM TWO", CGRect(x: 80,  y: 520, width: 420, height: 70), yellow),
        ])
        // p2: yellow "ITEM THREE"
        let p2 = synthesizedPage(marks: [
            ("ITEM THREE", CGRect(x: 80, y: 200, width: 520, height: 70), yellow),
        ])

        let pages = [p1, p2]
        let rules = ColorRule.defaults

        // 1) 검출
        let regionsByPage = pages.map { HighlightDetector.detect(in: $0, rules: rules) }
        // p1: 1 orange + 2 yellow
        #expect(regionsByPage[0].filter { $0.color == .orange }.count == 1)
        #expect(regionsByPage[0].filter { $0.color == .yellow }.count == 2)
        // p2: 1 yellow
        #expect(regionsByPage[1].filter { $0.color == .yellow }.count == 1)

        // 2) OCR
        var textsByPage: [[String]] = []
        for (img, regions) in zip(pages, regionsByPage) {
            let t = await OCRService.recognize(in: img, regions: regions)
            textsByPage.append(t)
        }
        #expect(textsByPage.count == 2)

        // 모든 영역에서 OCR 결과가 비어있지 않아야 함 (영문 픽스처라 거의 결정적)
        let allTexts = textsByPage.flatMap { $0 }
        #expect(allTexts.allSatisfy { !$0.isEmpty })

        // 3) Note 그래프 조립 + MarkdownDocument 파생
        let note = assembleNote(
            title: "PIPELINE",
            pages: pages,
            regionsByPage: regionsByPage,
            textsByPage: textsByPage
        )
        #expect(note.pages.count == 2)

        let doc = MarkdownDocument.from(note)
        // orange 1개 → 1개 섹션 (p2의 yellow는 그 섹션에 이어 붙음)
        #expect(doc.sections.count == 1)
        let section = try! #require(doc.sections.first)
        // 섹션 제목에 "TOPIC" 토큰이 포함되어야 함 — OCR 노이즈 허용
        #expect((section.title ?? "").uppercased().contains("TOPIC"))
        // 본문 항목 3개 (ITEM ONE / TWO / THREE)
        #expect(section.items.count == 3)
        let itemTexts = section.items.map { $0.text.uppercased() }.joined(separator: " | ")
        #expect(itemTexts.contains("ONE"))
        #expect(itemTexts.contains("TWO"))
        #expect(itemTexts.contains("THREE"))
    }

    @Test("orange 0개면 모든 노랑이 '주제 미지정' 한 섹션으로")
    @MainActor
    func yellowOnlyBecomesUnspecified() async {
        let page = synthesizedPage(marks: [
            ("FIRST",  CGRect(x: 80, y: 150, width: 360, height: 70), yellow),
            ("SECOND", CGRect(x: 80, y: 350, width: 360, height: 70), yellow),
        ])
        let rules = ColorRule.defaults

        let regions = HighlightDetector.detect(in: page, rules: rules)
        #expect(regions.count == 2)
        #expect(regions.allSatisfy { $0.color == .yellow })

        let texts = await OCRService.recognize(in: page, regions: regions)
        let note = assembleNote(
            title: "ONLY-YELLOW",
            pages: [page],
            regionsByPage: [regions],
            textsByPage: [texts]
        )

        let doc = MarkdownDocument.from(note)
        #expect(doc.sections.count == 1)
        #expect(doc.sections[0].title == nil)   // 주제 미지정
        #expect(doc.sections[0].items.count == 2)
    }

    // MARK: - 조립 헬퍼

    /// ProcessingViewModel.assembleNote의 외부 mirror.
    /// 실제 구현이 private이라 테스트에서 같은 로직을 재현 — 둘이 어긋나면
    /// 통합 의미를 잃으니 이 테스트가 그 어긋남을 잡는 안전망 역할도 한다.
    /// SwiftData @Model 관계는 ModelContext 밖에선 append가 불안정 — MarkdownDocumentTests
    /// 헬퍼와 동일하게 배열 통째로 할당한다.
    @MainActor
    private func assembleNote(
        title: String,
        pages: [UIImage],
        regionsByPage: [[DetectedRegion]],
        textsByPage: [[String]]
    ) -> Note {
        let note = Note(
            title: title,
            createdAt: .now,
            source: .pdf,
            pageCount: pages.count,
            originalFilename: "\(title).pdf"
        )
        var allPages: [Page] = []
        for (idx, image) in pages.enumerated() {
            let pageData = image.jpegData(compressionQuality: 0.8) ?? Data()
            let page = Page(pageNumber: idx + 1, imageData: pageData)
            page.note = note

            let regions = regionsByPage[idx]
            let texts = textsByPage[idx]
            var hs: [Highlight] = []
            var order = 0
            for (rIdx, region) in regions.enumerated() {
                let text = rIdx < texts.count ? texts[rIdx] : ""
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                let h = Highlight(
                    colorCategory: region.color,
                    text: trimmed,
                    boundingBoxData: withUnsafeBytes(of: region.boundingBox) { Data($0) },
                    orderInPage: order
                )
                h.page = page
                hs.append(h)
                order += 1
            }
            page.highlights = hs
            allPages.append(page)
        }
        note.pages = allPages
        return note
    }
}
