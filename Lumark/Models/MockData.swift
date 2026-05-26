//
//  MockData.swift
//  Lumark
//
//  디자인 단계용 가짜 데이터. ResultView/HomeView Preview 채우기에 사용.
//  실제 파이프라인(Day 5+) 연결되면 이 파일은 제거 또는 #if DEBUG로 한정.
//
//  디자인 시안의 "항생제정리" 노트를 그대로 옮김. spec §6 마크다운 예시와 일치.
//

import Foundation
import CoreGraphics
import SwiftData

enum MockData {

    // MARK: - bounding box 인코딩 헬퍼

    /// 디자인 단계에서 bbox는 실제 좌표가 필요 없음 — placeholder만.
    private static var placeholderBox: Data {
        let zero = CGRect.zero
        return withUnsafeBytes(of: zero) { Data($0) }
    }

    // MARK: - 항생제정리 (4페이지)

    /// 시안의 "항생제정리" — SwiftData 컨테이너 외부에서 단순히 객체로 생성.
    /// Preview에서 `.modelContainer(... inMemory: true)` 컨테이너에 insert 하거나
    /// 그냥 객체 그대로 사용 가능.
    @MainActor
    static func antibioticsNote() -> Note {
        let note = Note(
            title: "항생제정리",
            createdAt: dateOf("2026-05-24"),
            source: .pdf,
            pageCount: 4,
            originalFilename: "항생제정리.pdf"
        )

        // ── Page 1: 항생제의 분류 (주황 1개 + 노랑 2개 + 주황 1개 도입)
        let p1 = Page(pageNumber: 1, imageData: Data())
        p1.note = note
        p1.highlights = [
            Highlight(colorCategory: .orange, text: "항생제의 분류",
                      boundingBoxData: placeholderBox, orderInPage: 0),
            Highlight(colorCategory: .yellow, text: "베타락탐계는 세포벽 합성을 억제",
                      boundingBoxData: placeholderBox, orderInPage: 1),
            Highlight(colorCategory: .yellow, text: "페니실린 알레르기 환자 주의",
                      boundingBoxData: placeholderBox, orderInPage: 2),
            Highlight(colorCategory: .orange, text: "세팔로스포린은 1~5세대까지",
                      boundingBoxData: placeholderBox, orderInPage: 3),
        ]
        p1.highlights.forEach { $0.page = p1 }

        // ── Page 2: 부작용 모니터링 (주황 = 섹션, 노랑/분홍 본문)
        let p2 = Page(pageNumber: 2, imageData: Data())
        p2.note = note
        p2.highlights = [
            Highlight(colorCategory: .orange, text: "부작용 모니터링",
                      boundingBoxData: placeholderBox, orderInPage: 0),
            Highlight(colorCategory: .yellow, text: "신독성 신호 — BUN/Cr 상승",
                      boundingBoxData: placeholderBox, orderInPage: 1),
            Highlight(colorCategory: .pink,   text: "청신경 독성 — 가역적",
                      boundingBoxData: placeholderBox, orderInPage: 2),
        ]
        p2.highlights.forEach { $0.page = p2 }

        // ── Page 3: 추가 부작용 항목
        let p3 = Page(pageNumber: 3, imageData: Data())
        p3.note = note
        p3.highlights = [
            Highlight(colorCategory: .pink,  text: "위막성 대장염 — 클로스트리디움 디피실",
                      boundingBoxData: placeholderBox, orderInPage: 0),
            Highlight(colorCategory: .blue,  text: "참고: 항생제 감수성 검사(AST) 결과 우선",
                      boundingBoxData: placeholderBox, orderInPage: 1),
        ]
        p3.highlights.forEach { $0.page = p3 }

        // ── Page 4: 추가 메모용 분홍 1개
        let p4 = Page(pageNumber: 4, imageData: Data())
        p4.note = note
        p4.highlights = [
            Highlight(colorCategory: .pink,  text: "위막성 대장염 의심 시 메트로니다졸 또는 반코마이신 경구",
                      boundingBoxData: placeholderBox, orderInPage: 0),
        ]
        p4.highlights.forEach { $0.page = p4 }

        note.pages = [p1, p2, p3, p4]
        return note
    }

    // MARK: - 최근 작업 목록용 추가 mock

    @MainActor
    static func recentNotes() -> [Note] {
        [
            antibioticsNote(),
            simpleNote(
                title: "심전도 판독 요점",
                date: "2026-05-22",
                pageCount: 12,
                colors: [.yellow, .blue]
            ),
            simpleNote(
                title: "당뇨병 약물 정리",
                date: "2026-05-19",
                pageCount: 8,
                colors: [.yellow, .orange]
            ),
        ]
    }

    @MainActor
    private static func simpleNote(
        title: String,
        date: String,
        pageCount: Int,
        colors: [ColorCategory]
    ) -> Note {
        let note = Note(
            title: title,
            createdAt: dateOf(date),
            source: .pdf,
            pageCount: pageCount
        )
        // 색 dot 표시용으로 각 색마다 한 페이지에 한 하이라이트씩
        let page = Page(pageNumber: 1, imageData: Data())
        page.note = note
        page.highlights = colors.enumerated().map { idx, c in
            let h = Highlight(
                colorCategory: c,
                text: "샘플",
                boundingBoxData: placeholderBox,
                orderInPage: idx
            )
            h.page = page
            return h
        }
        note.pages = [page]
        return note
    }

    private static func dateOf(_ ymd: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "ko_KR")
        return f.date(from: ymd) ?? .now
    }

    // MARK: - Preview용 in-memory ModelContainer

    @MainActor
    static func previewContainer(withMockNotes: Bool = true) -> ModelContainer {
        let schema = Schema([Note.self, Page.self, Highlight.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])

        if withMockNotes {
            for note in recentNotes() {
                container.mainContext.insert(note)
            }
        }
        return container
    }
}
