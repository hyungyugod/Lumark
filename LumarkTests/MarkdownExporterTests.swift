//
//  MarkdownExporterTests.swift
//  LumarkTests
//
//  spec §6 출력 포맷 검증.
//

import Testing
import Foundation
@testable import Lumark

@Suite("MarkdownExporter — spec §6 출력 포맷")
struct MarkdownExporterTests {

    private func fixedDate(_ ymd: String = "2026-05-21") -> Date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: ymd)!
    }

    // 짧은 골든: 가장 단순한 노트
    @Test("제목 + 단일 섹션 + 글머리 2개")
    func basicShape() {
        let doc = MarkdownDocument(
            title: "TEST",
            sections: [
                MarkdownSection(
                    id: UUID(),
                    title: "분류",
                    items: [
                        MarkdownItem(id: UUID(), color: .yellow, text: "A"),
                        MarkdownItem(id: UUID(), color: .yellow, text: "B"),
                    ]
                )
            ],
            pinkItems: [],
            blueItems: [],
            createdAt: fixedDate(),
            pageCount: 1,
            originalFilename: "TEST.pdf"
        )

        let out = MarkdownExporter.export(doc)
        let expected = """
        # TEST

        ## 분류

        - A
        - B

        ---

        > 변환 정보: TEST.pdf · 1페이지 · 2026-05-21 변환 · 🟡 2, 🟠 1

        """
        #expect(out == expected)
    }

    @Test("주제 미지정 섹션 (title == nil)")
    func nilTitleBecomesPlaceholder() {
        let doc = MarkdownDocument(
            title: "T",
            sections: [
                MarkdownSection(
                    id: UUID(),
                    title: nil,
                    items: [MarkdownItem(id: UUID(), color: .yellow, text: "선행")]
                )
            ],
            pinkItems: [], blueItems: [],
            createdAt: fixedDate(),
            pageCount: 1,
            originalFilename: nil
        )

        let out = MarkdownExporter.export(doc)
        #expect(out.contains("## (주제 미지정)"))
        #expect(out.contains("- 선행"))
    }

    @Test("분홍·파랑은 '추가 메모' 섹션, 사용자 라벨 우선")
    func supplementaryWithCustomLabels() {
        let doc = MarkdownDocument(
            title: "T",
            sections: [],
            pinkItems: [MarkdownItem(id: UUID(), color: .pink, text: "p1")],
            blueItems: [MarkdownItem(id: UUID(), color: .blue, text: "b1")],
            createdAt: fixedDate(),
            pageCount: 1,
            originalFilename: nil
        )

        let out = MarkdownExporter.export(doc, pinkLabel: "주의", blueLabel: "출처")
        #expect(out.contains("### 추가 메모"))
        #expect(out.contains("**주의**"))
        #expect(out.contains("**출처**"))
        #expect(out.contains("- p1"))
        #expect(out.contains("- b1"))
    }

    @Test("분홍·파랑 라벨이 비어있으면 기본값 사용")
    func supplementaryWithDefaultLabels() {
        let doc = MarkdownDocument(
            title: "T",
            sections: [],
            pinkItems: [MarkdownItem(id: UUID(), color: .pink, text: "p1")],
            blueItems: [],
            createdAt: fixedDate(),
            pageCount: 1,
            originalFilename: nil
        )

        let out = MarkdownExporter.export(doc, pinkLabel: "  ", blueLabel: nil)
        #expect(out.contains("**보충 (분홍)**"))
    }

    @Test("본문 0개 + 추가 메모만")
    func onlySupplementary() {
        let doc = MarkdownDocument(
            title: "T",
            sections: [],
            pinkItems: [MarkdownItem(id: UUID(), color: .pink, text: "only")],
            blueItems: [],
            createdAt: fixedDate(),
            pageCount: 1,
            originalFilename: nil
        )

        let out = MarkdownExporter.export(doc)
        // 본문 섹션 헤더(line이 "## "로 시작)는 없어야 함 — ### 추가 메모는 supplementary라 OK
        let lines = out.components(separatedBy: "\n")
        let hasBodyHeader = lines.contains { $0.hasPrefix("## ") }
        #expect(hasBodyHeader == false)
        #expect(out.contains("### 추가 메모"))
    }

    @Test("originalFilename 없으면 '제목.pdf' 사용")
    func footerFilenameFallback() {
        let doc = MarkdownDocument(
            title: "항생제정리",
            sections: [],
            pinkItems: [MarkdownItem(id: UUID(), color: .pink, text: "x")],
            blueItems: [],
            createdAt: fixedDate(),
            pageCount: 3,
            originalFilename: nil
        )

        let out = MarkdownExporter.export(doc)
        #expect(out.contains("> 변환 정보: 항생제정리.pdf · 3페이지 · 2026-05-21 변환"))
    }

    @Test("주황만 있고 본문 없는 섹션은 헤더만 찍힘")
    func orangeOnlySection() {
        let doc = MarkdownDocument(
            title: "T",
            sections: [
                MarkdownSection(id: UUID(), title: "제목만", items: []),
                MarkdownSection(id: UUID(), title: "본문있음", items: [
                    MarkdownItem(id: UUID(), color: .yellow, text: "글")
                ]),
            ],
            pinkItems: [], blueItems: [],
            createdAt: fixedDate(),
            pageCount: 1,
            originalFilename: nil
        )

        let out = MarkdownExporter.export(doc)
        #expect(out.contains("## 제목만"))
        #expect(out.contains("## 본문있음"))
        #expect(out.contains("- 글"))
    }

    // 통합: from(Note) → export 전체 흐름
    @Test("Note → MarkdownDocument → Markdown 풀 파이프")
    func endToEndPipeline() {
        let n = Note(
            title: "항생제정리",
            createdAt: fixedDate("2026-05-24"),
            sourceType: "pdf",
            pageCount: 2,
            originalFilename: "항생제정리.pdf"
        )

        let p1 = Page(pageNumber: 1, imageData: Data())
        p1.note = n
        let h1a = Highlight(colorCategory: .orange, text: "항생제의 분류",
                            boundingBoxData: Data(), orderInPage: 0)
        let h1b = Highlight(colorCategory: .yellow, text: "베타락탐계",
                            boundingBoxData: Data(), orderInPage: 1)
        [h1a, h1b].forEach { $0.page = p1 }
        p1.highlights = [h1a, h1b]

        let p2 = Page(pageNumber: 2, imageData: Data())
        p2.note = n
        let h2a = Highlight(colorCategory: .pink, text: "주의사항",
                            boundingBoxData: Data(), orderInPage: 0)
        h2a.page = p2
        p2.highlights = [h2a]

        n.pages = [p1, p2]

        let doc = MarkdownDocument.from(n)
        let out = MarkdownExporter.export(doc)

        #expect(out.contains("# 항생제정리"))
        #expect(out.contains("## 항생제의 분류"))
        #expect(out.contains("- 베타락탐계"))
        #expect(out.contains("### 추가 메모"))
        #expect(out.contains("- 주의사항"))
        #expect(out.contains("> 변환 정보: 항생제정리.pdf · 2페이지 · 2026-05-24 변환"))
    }
}
