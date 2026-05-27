//
//  PDFExporterTests.swift
//  LumarkTests
//
//  PDFExporter는 외부 자산(폰트, CoreText 페이지네이션) 의존이라
//  내용 정확성은 정성 검증 영역. 단위 테스트는 다음 invariant만 잠근다:
//
//    1. 파일이 만들어지고 위치한다
//    2. 유효한 PDF다 (PDFKit으로 다시 열 수 있음)
//    3. 최소 1페이지 이상
//    4. 빈 문서면 예외 없이 footer만 있는 1페이지 PDF
//

import Testing
import Foundation
import PDFKit
@testable import Lumark

@Suite("PDFExporter — invariants")
struct PDFExporterTests {

    private func makeDoc() -> MarkdownDocument {
        // 병렬 테스트 충돌 방지 — 매번 unique title
        MarkdownDocument(
            title: "테스트노트-\(UUID().uuidString.prefix(8))",
            sections: [
                MarkdownSection(id: UUID(), title: "섹션1", items: [
                    MarkdownItem(id: UUID(), color: .yellow, text: "글머리1"),
                    MarkdownItem(id: UUID(), color: .yellow, text: "글머리2"),
                ])
            ],
            createdAt: .now,
            pageCount: 1,
            originalFilename: "테스트.pdf"
        )
    }

    @Test("기본 문서를 PDF로 내보내면 유효한 파일")
    func basicExport() throws {
        let url = try PDFExporter.export(makeDoc())
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(FileManager.default.fileExists(atPath: url.path))
        let pdf = try #require(PDFDocument(url: url))
        #expect(pdf.pageCount >= 1)
    }

    @Test("본문 텍스트가 PDF에 포함됨")
    func bodyTextIncluded() throws {
        let url = try PDFExporter.export(makeDoc())
        defer { try? FileManager.default.removeItem(at: url) }

        let pdf = try #require(PDFDocument(url: url))
        let text = (0..<pdf.pageCount)
            .compactMap { pdf.page(at: $0)?.string }
            .joined(separator: "\n")
        #expect(text.contains("섹션1"))
        #expect(text.contains("글머리1"))
        #expect(text.contains("글머리2"))
    }

    @Test("빈 섹션의 문서도 PDF는 만들어짐 (footer만)")
    func emptyDoc() throws {
        let empty = MarkdownDocument(
            title: "비어있음",
            sections: [],
            createdAt: .now,
            pageCount: 0,
            originalFilename: nil
        )
        let url = try PDFExporter.export(empty)
        defer { try? FileManager.default.removeItem(at: url) }

        let pdf = try #require(PDFDocument(url: url))
        #expect(pdf.pageCount >= 1)
    }

    @Test("파일명 sanitize — '/' 와 ':'은 '-'로")
    func filenameSanitization() throws {
        let doc = MarkdownDocument(
            title: "위/아래:옆-\(UUID().uuidString.prefix(8))",
            sections: [],
            createdAt: .now,
            pageCount: 1,
            originalFilename: nil
        )
        let url = try PDFExporter.export(doc)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(url.lastPathComponent.contains("/") == false)
        // ':' 도 없어야 함 (Path separator 아니지만 우리 sanitizer가 처리)
        #expect(url.lastPathComponent.contains(":") == false)
    }
}
