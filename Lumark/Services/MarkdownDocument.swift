//
//  MarkdownDocument.swift
//  Lumark
//
//  Note → 마크다운 문서 구조 파생. spec §6 알고리즘.
//
//  구조 (v0.1: 노랑/주황만):
//    - 주황 등장 = 새 섹션 시작 (제목은 주황 텍스트)
//    - 첫 주황 이전의 노랑 = "주제 미지정" 섹션
//    - 분홍/파랑은 v0.1에서 미구현 — Highlight로 들어와도 무시.
//

import Foundation

/// 마크다운 한 줄 (노랑 = 글머리표 본문).
struct MarkdownItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let color: ColorCategory
    let text: String
    /// 이 항목이 등장한 페이지 (1-indexed). 페이지 매핑 표 생성에 사용.
    let pageNumber: Int

    nonisolated init(id: UUID, color: ColorCategory, text: String, pageNumber: Int = 0) {
        self.id = id
        self.color = color
        self.text = text
        self.pageNumber = pageNumber
    }
}

/// 섹션 = 주황 제목 + 그 아래 노랑 글머리표들
struct MarkdownSection: Identifiable, Equatable, Sendable {
    let id: UUID
    /// nil이면 "주제 미지정" (첫 주황 이전 영역)
    let title: String?
    let items: [MarkdownItem]
    /// 섹션 제목이 등장한 페이지 (제목 없는 섹션은 첫 item의 페이지).
    let pageNumber: Int

    nonisolated init(id: UUID, title: String?, items: [MarkdownItem], pageNumber: Int = 0) {
        self.id = id
        self.title = title
        self.items = items
        self.pageNumber = pageNumber
    }
}

/// 마크다운 한 문서 = 본문 섹션들.
/// 도메인 값 타입 — 백그라운드에서도 안전하게 다뤄야 하므로 전체 nonisolated.
struct MarkdownDocument: Equatable, Sendable {
    let title: String
    let sections: [MarkdownSection]
    let createdAt: Date
    let pageCount: Int
    let originalFilename: String?

    nonisolated init(
        title: String,
        sections: [MarkdownSection],
        createdAt: Date,
        pageCount: Int,
        originalFilename: String?
    ) {
        self.title = title
        self.sections = sections
        self.createdAt = createdAt
        self.pageCount = pageCount
        self.originalFilename = originalFilename
    }

    nonisolated var hasAnyContent: Bool { !sections.isEmpty }
}

// MARK: - 파생 로직

/// Highlight + 페이지 번호 묶음 (내부 사용).
fileprivate struct OrderedHighlight {
    let highlight: Highlight
    let pageNumber: Int
}

extension MarkdownDocument {
    /// Note의 페이지·하이라이트를 정렬해 MarkdownDocument로 변환.
    /// spec §6 의사 코드. v0.1은 노랑/주황만 처리.
    static func from(_ note: Note) -> MarkdownDocument {
        let ordered: [OrderedHighlight] = note.pages
            .sorted { $0.pageNumber < $1.pageNumber }
            .flatMap { page in
                page.highlights
                    .sorted { $0.orderInPage < $1.orderInPage }
                    .map { OrderedHighlight(highlight: $0, pageNumber: page.pageNumber) }
            }

        // 활성 색만 추려서 섹션 분할 (v0.1 = 노랑/주황)
        let active = ordered.filter {
            ColorCategory.activeInV01.contains($0.highlight.colorCategory)
        }
        let sections = splitByOrange(active)

        return MarkdownDocument(
            title: note.title,
            sections: sections,
            createdAt: note.createdAt,
            pageCount: note.pageCount,
            originalFilename: note.originalFilename
        )
    }

    /// 주황 등장 인덱스로 섹션을 자른다.
    ///
    /// 페이지 헤더 dedup: 한 노트가 여러 페이지에 걸쳐 같은 제목(예: 강의명)을
    /// 페이지마다 주황으로 반복해 칠한 경우, 같은 텍스트의 두 번째 이후 주황 표시는
    /// 무시한다. 직후의 노랑 글머리표들은 직전에 열려있던 섹션에 이어 붙는다.
    /// (의도적으로 같은 제목의 두 섹션을 만들고 싶다면 한쪽 제목에 공백 등으로
    /// 변형을 줘야 함 — v0.1 트레이드오프.)
    private static func splitByOrange(_ highlights: [OrderedHighlight]) -> [MarkdownSection] {
        var result: [MarkdownSection] = []
        var currentTitle: String? = nil
        var currentItems: [MarkdownItem] = []
        var currentSectionPage: Int = 0
        var seenOrangeTexts: Set<String> = []

        func flush() {
            if currentTitle != nil || !currentItems.isEmpty {
                result.append(MarkdownSection(
                    id: UUID(),
                    title: currentTitle,
                    items: currentItems,
                    pageNumber: currentSectionPage
                ))
            }
            currentItems = []
            currentTitle = nil
            currentSectionPage = 0
        }

        for entry in highlights {
            let h = entry.highlight
            switch h.colorCategory {
            case .orange:
                let key = h.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if seenOrangeTexts.contains(key) {
                    // 페이지 헤더 반복으로 간주: 새 섹션 만들지 않고 현재 섹션 유지.
                    continue
                }
                flush()
                currentTitle = h.text
                currentSectionPage = entry.pageNumber
                seenOrangeTexts.insert(key)
            case .yellow:
                if currentSectionPage == 0 { currentSectionPage = entry.pageNumber }
                currentItems.append(MarkdownItem(
                    id: h.id,
                    color: .yellow,
                    text: h.text,
                    pageNumber: entry.pageNumber
                ))
            default:
                break
            }
        }
        flush()
        return result
    }
}

// MARK: - 색별 통계

extension MarkdownDocument {
    /// 색별 하이라이트 개수 (UI footer/통계 표시용).
    nonisolated var colorCounts: [ColorCategory: Int] {
        var counts: [ColorCategory: Int] = [:]
        for section in sections {
            counts[.yellow, default: 0] += section.items.filter { $0.color == .yellow }.count
            if section.title != nil {
                counts[.orange, default: 0] += 1
            }
        }
        return counts
    }

    /// 페이지 → 섹션 매핑 (마크다운 footer의 표 생성용).
    /// 한 페이지에 여러 섹션이 등장할 수 있고, 한 섹션이 여러 페이지에 걸칠 수 있음.
    nonisolated var pageToSectionMap: [(page: Int, sectionTitle: String, itemCount: Int)] {
        var result: [(page: Int, sectionTitle: String, itemCount: Int)] = []
        for section in sections {
            let sectionPages = Set(section.items.map { $0.pageNumber } + [section.pageNumber])
                .filter { $0 > 0 }
                .sorted()
            for page in sectionPages {
                let count = section.items.filter { $0.pageNumber == page }.count
                result.append((
                    page: page,
                    sectionTitle: section.title ?? "(주제 미지정)",
                    itemCount: count
                ))
            }
        }
        return result.sorted { $0.page < $1.page }
    }
}
