//
//  MarkdownDocumentTests.swift
//  LumarkTests
//
//  spec §6 알고리즘의 fixture 단위 테스트.
//
//  목적: spec §7 S3 게이트("섹션 분할 일치 ≥ 90%")의 절반은 OCR 텍스트가
//  주어졌을 때 우리가 그걸 올바른 섹션 구조로 변환하는가 — 이건 입력 OCR과
//  무관하게 알고리즘 자체로 검증 가능. 그 부분을 여기서 100% 잠근다.
//

import Testing
import Foundation
@testable import Lumark

@Suite("MarkdownDocument — spec §6 알고리즘")
struct MarkdownDocumentTests {

    // MARK: - Helpers

    /// 페이지 묶음을 한 줄로 짧게 만드는 헬퍼.
    /// `("o:항생제분류", "y:노랑1", "y:노랑2", "p:분홍1")` 같은 식.
    private func note(
        title: String = "T",
        pages: [[String]]
    ) -> Note {
        let n = Note(title: title, sourceType: "pdf", pageCount: pages.count)
        var allPages: [Page] = []
        for (idx, lines) in pages.enumerated() {
            let p = Page(pageNumber: idx + 1, imageData: Data())
            p.note = n
            var hs: [Highlight] = []
            for (i, line) in lines.enumerated() {
                let (color, text) = parse(line)
                let h = Highlight(
                    colorCategory: color,
                    text: text,
                    boundingBoxData: Data(),
                    orderInPage: i
                )
                h.page = p
                hs.append(h)
            }
            p.highlights = hs
            allPages.append(p)
        }
        n.pages = allPages
        return n
    }

    private func parse(_ line: String) -> (ColorCategory, String) {
        let parts = line.split(separator: ":", maxSplits: 1)
        let key = String(parts[0])
        let text = parts.count > 1 ? String(parts[1]) : ""
        let color: ColorCategory = switch key {
        case "y": .yellow
        case "o": .orange
        case "p": .pink
        case "b": .blue
        default: .yellow
        }
        return (color, text)
    }

    // MARK: - 빈 입력

    @Test("빈 노트는 빈 document")
    func emptyNote() {
        let n = note(pages: [])
        let doc = MarkdownDocument.from(n)
        #expect(doc.sections.isEmpty)
        #expect(doc.pinkItems.isEmpty)
        #expect(doc.blueItems.isEmpty)
        #expect(doc.hasAnyContent == false)
    }

    @Test("페이지는 있는데 하이라이트 0개")
    func pagesButNoHighlights() {
        let n = note(pages: [[], [], []])
        let doc = MarkdownDocument.from(n)
        #expect(doc.sections.isEmpty)
        #expect(doc.hasAnyContent == false)
    }

    // MARK: - 노랑만 / 주황 없음

    @Test("주황 0개, 노랑만 있으면 '주제 미지정' 섹션 하나")
    func yellowOnly() {
        let n = note(pages: [
            ["y:A", "y:B", "y:C"],
        ])
        let doc = MarkdownDocument.from(n)
        #expect(doc.sections.count == 1)
        #expect(doc.sections[0].title == nil)
        #expect(doc.sections[0].items.map(\.text) == ["A", "B", "C"])
    }

    // MARK: - 주황 한 개 (제목 + 본문)

    @Test("주황 하나로 시작, 그 뒤 노랑 = 한 섹션")
    func singleOrangeSection() {
        let n = note(pages: [
            ["o:섹션 제목", "y:글머리1", "y:글머리2"],
        ])
        let doc = MarkdownDocument.from(n)
        #expect(doc.sections.count == 1)
        #expect(doc.sections[0].title == "섹션 제목")
        #expect(doc.sections[0].items.map(\.text) == ["글머리1", "글머리2"])
    }

    // MARK: - 주황 여러 개

    @Test("주황 2개 = 섹션 2개")
    func twoSections() {
        let n = note(pages: [
            ["o:첫제목", "y:a1", "o:둘제목", "y:b1", "y:b2"],
        ])
        let doc = MarkdownDocument.from(n)
        #expect(doc.sections.count == 2)
        #expect(doc.sections[0].title == "첫제목")
        #expect(doc.sections[0].items.map(\.text) == ["a1"])
        #expect(doc.sections[1].title == "둘제목")
        #expect(doc.sections[1].items.map(\.text) == ["b1", "b2"])
    }

    @Test("첫 주황 이전 노랑 = '주제 미지정' 섹션 + 본 섹션")
    func leadingYellowsBeforeOrange() {
        let n = note(pages: [
            ["y:선행1", "y:선행2", "o:본제목", "y:본글1"],
        ])
        let doc = MarkdownDocument.from(n)
        #expect(doc.sections.count == 2)
        #expect(doc.sections[0].title == nil)
        #expect(doc.sections[0].items.map(\.text) == ["선행1", "선행2"])
        #expect(doc.sections[1].title == "본제목")
        #expect(doc.sections[1].items.map(\.text) == ["본글1"])
    }

    @Test("주황만 있고 그 아래 노랑 0개 = 빈 섹션도 유지")
    func orangeWithoutBody() {
        let n = note(pages: [
            ["o:제목만", "o:다음제목", "y:글1"],
        ])
        let doc = MarkdownDocument.from(n)
        #expect(doc.sections.count == 2)
        #expect(doc.sections[0].title == "제목만")
        #expect(doc.sections[0].items.isEmpty)
        #expect(doc.sections[1].title == "다음제목")
        #expect(doc.sections[1].items.map(\.text) == ["글1"])
    }

    // MARK: - 분홍 / 파랑 분리

    @Test("분홍·파랑은 본 섹션에 안 들어가고 별도 풀로 분리")
    func pinkAndBlueSeparated() {
        let n = note(pages: [
            ["o:주제", "y:노랑1", "p:분홍1", "y:노랑2", "b:파랑1", "p:분홍2"],
        ])
        let doc = MarkdownDocument.from(n)
        #expect(doc.sections.count == 1)
        #expect(doc.sections[0].title == "주제")
        // 본 섹션에는 노랑만
        #expect(doc.sections[0].items.map(\.text) == ["노랑1", "노랑2"])
        #expect(doc.pinkItems.map(\.text) == ["분홍1", "분홍2"])
        #expect(doc.blueItems.map(\.text) == ["파랑1"])
        #expect(doc.hasSupplementary)
    }

    @Test("분홍/파랑만 있고 본문 0개")
    func onlySupplementary() {
        let n = note(pages: [
            ["p:분홍1", "b:파랑1", "b:파랑2"],
        ])
        let doc = MarkdownDocument.from(n)
        #expect(doc.sections.isEmpty)
        #expect(doc.pinkItems.map(\.text) == ["분홍1"])
        #expect(doc.blueItems.map(\.text) == ["파랑1", "파랑2"])
        #expect(doc.hasAnyContent)
    }

    // MARK: - 페이지 경계 정렬

    @Test("페이지 순서대로, 각 페이지 내 orderInPage 순으로 합쳐짐")
    func pageBoundaryOrder() {
        let n = note(pages: [
            ["o:p1제목", "y:p1글"],
            ["y:p2글"],
            ["o:p3제목", "y:p3글"],
        ])
        let doc = MarkdownDocument.from(n)
        #expect(doc.sections.count == 2)
        #expect(doc.sections[0].title == "p1제목")
        // p1 노랑 + p2 노랑이 같은 섹션 (p1제목 아래)
        #expect(doc.sections[0].items.map(\.text) == ["p1글", "p2글"])
        #expect(doc.sections[1].title == "p3제목")
        #expect(doc.sections[1].items.map(\.text) == ["p3글"])
    }

    @Test("페이지가 역순으로 입력돼도 pageNumber 기준 정렬")
    func unsortedPagesGetSorted() {
        let n = Note(title: "T", sourceType: "pdf", pageCount: 2)

        let p2 = Page(pageNumber: 2, imageData: Data())
        p2.note = n
        let h2 = Highlight(colorCategory: .yellow, text: "p2", boundingBoxData: Data(), orderInPage: 0)
        h2.page = p2
        p2.highlights = [h2]

        let p1 = Page(pageNumber: 1, imageData: Data())
        p1.note = n
        let h1 = Highlight(colorCategory: .orange, text: "주제", boundingBoxData: Data(), orderInPage: 0)
        h1.page = p1
        p1.highlights = [h1]

        // 일부러 p2 먼저
        n.pages = [p2, p1]

        let doc = MarkdownDocument.from(n)
        #expect(doc.sections.count == 1)
        #expect(doc.sections[0].title == "주제")
        #expect(doc.sections[0].items.map(\.text) == ["p2"])
    }

    @Test("orderInPage가 뒤섞여도 정렬됨")
    func unsortedOrderInPageGetsSorted() {
        let n = Note(title: "T", sourceType: "pdf", pageCount: 1)
        let p = Page(pageNumber: 1, imageData: Data())
        p.note = n
        let hOrange = Highlight(colorCategory: .orange, text: "주제", boundingBoxData: Data(), orderInPage: 0)
        let hY2 = Highlight(colorCategory: .yellow, text: "둘째", boundingBoxData: Data(), orderInPage: 2)
        let hY1 = Highlight(colorCategory: .yellow, text: "첫째", boundingBoxData: Data(), orderInPage: 1)
        [hOrange, hY1, hY2].forEach { $0.page = p }
        // 일부러 뒤섞어 넣음
        p.highlights = [hY2, hOrange, hY1]
        n.pages = [p]

        let doc = MarkdownDocument.from(n)
        #expect(doc.sections.count == 1)
        #expect(doc.sections[0].title == "주제")
        #expect(doc.sections[0].items.map(\.text) == ["첫째", "둘째"])
    }

    // MARK: - spec §6 예시 골든 케이스

    @Test("spec §6 항생제정리 시나리오 — 골든")
    func specGoldenAntibiotics() {
        let n = note(title: "항생제정리", pages: [
            // p1
            ["o:항생제의 분류", "y:베타락탐계는 세포벽 합성을 억제", "y:페니실린 알레르기 환자 주의", "o:세팔로스포린은 1~5세대까지"],
            // p2
            ["o:부작용 모니터링", "y:신독성 신호 — BUN/Cr 상승", "p:청신경 독성 — 가역적"],
            // p3
            ["p:위막성 대장염 — 클로스트리디움 디피실", "b:참고: AST 결과 우선"],
        ])
        let doc = MarkdownDocument.from(n)

        // 본 섹션
        #expect(doc.title == "항생제정리")
        #expect(doc.sections.count == 3)
        #expect(doc.sections[0].title == "항생제의 분류")
        #expect(doc.sections[0].items.map(\.text) ==
            ["베타락탐계는 세포벽 합성을 억제", "페니실린 알레르기 환자 주의"])
        #expect(doc.sections[1].title == "세팔로스포린은 1~5세대까지")
        #expect(doc.sections[1].items.isEmpty)
        #expect(doc.sections[2].title == "부작용 모니터링")
        #expect(doc.sections[2].items.map(\.text) == ["신독성 신호 — BUN/Cr 상승"])

        // 추가 메모
        #expect(doc.pinkItems.map(\.text) ==
            ["청신경 독성 — 가역적", "위막성 대장염 — 클로스트리디움 디피실"])
        #expect(doc.blueItems.map(\.text) == ["참고: AST 결과 우선"])
    }
}
