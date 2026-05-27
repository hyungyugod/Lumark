//
//  MarkdownExporter.swift
//  Lumark
//
//  MarkdownDocument → 마크다운 텍스트.
//  v0.1 출력 dialect:
//    - CommonMark (기본) — Notion·GitHub·Obsidian 호환
//    - Obsidian — ==형광펜== 래핑 추가 (옵션)
//

import Foundation

enum MarkdownDialect: String, Sendable, CaseIterable {
    case commonMark = "CommonMark"
    case obsidian = "Obsidian"

    nonisolated var description: String {
        switch self {
        case .commonMark: return "표준 (Notion·GitHub 호환)"
        case .obsidian:   return "Obsidian (==형광펜== 래핑)"
        }
    }
}

enum MarkdownExporter {

    /// MarkdownDocument를 마크다운 텍스트로 직렬화.
    /// - parameters:
    ///   - dialect: CommonMark / Obsidian
    ///   - includePageMap: 페이지 매핑 표 포함 여부 (spec §6 예시)
    static func export(
        _ doc: MarkdownDocument,
        dialect: MarkdownDialect = .commonMark,
        includePageMap: Bool = false
    ) -> String {
        var out = ""

        // 제목
        out += "# \(doc.title)\n\n"

        // 본문 섹션
        for section in doc.sections {
            let title = section.title ?? "(주제 미지정)"
            out += "## \(title)\n\n"

            if !section.items.isEmpty {
                for item in section.items {
                    out += "- \(format(item.text, color: item.color, dialect: dialect))\n"
                }
                out += "\n"
            }
        }

        // 페이지 매핑 표 (spec §6 옵션)
        if includePageMap {
            let entries = doc.pageToSectionMap
            if !entries.isEmpty {
                out += "---\n\n"
                out += "| 페이지 | 매핑된 섹션 |\n"
                out += "|---|---|\n"
                for entry in entries {
                    let detail = entry.itemCount > 0
                        ? "\(entry.sectionTitle) (항목 \(entry.itemCount))"
                        : entry.sectionTitle
                    out += "| p.\(entry.page) | \(detail) |\n"
                }
                out += "\n"
            }
        }

        // 변환 정보 footer
        out += "---\n\n"
        out += "> 변환 정보: \(footerInfo(for: doc))\n"

        return out
    }

    // MARK: - dialect별 inline 포맷

    /// Obsidian의 형광펜 문법은 `==text==`. CommonMark는 그대로.
    private static func format(_ text: String, color: ColorCategory, dialect: MarkdownDialect) -> String {
        switch dialect {
        case .commonMark:
            return text
        case .obsidian:
            // ==형광펜== 으로 래핑. (단, 이미 ==포함된 텍스트는 escape 처리)
            let escaped = text.replacingOccurrences(of: "==", with: "= =")
            return "==\(escaped)=="
        }
    }

    // MARK: - footer

    private static func footerInfo(for doc: MarkdownDocument) -> String {
        let filename = doc.originalFilename ?? "\(doc.title).pdf"
        let dateStr = dateFormatter.string(from: doc.createdAt)
        let counts = doc.colorCounts
        let countSummary = ColorCategory.activeInV01
            .compactMap { c -> String? in
                let n = counts[c] ?? 0
                return n > 0 ? "\(label(for: c)) \(n)" : nil
            }
            .joined(separator: ", ")

        var base = "\(filename) · \(doc.pageCount)페이지 · \(dateStr) 변환"
        if !countSummary.isEmpty {
            base += " · \(countSummary)"
        }
        return base
    }

    private static func label(for c: ColorCategory) -> String {
        switch c {
        case .yellow: return "🟡"
        case .orange: return "🟠"
        case .pink:   return "🩷"  // v0.1 미사용
        case .blue:   return "🔵"  // v0.1 미사용
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

