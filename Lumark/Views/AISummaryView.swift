//
//  AISummaryView.swift
//  Lumark
//
//  AI 정리본(마크다운 문자열) 표시 시트. ResultView에서 생성 직후/다시 열 때 띄운다.
//
//  MarkdownBodyView는 형광펜에서 파생된 "구조화된" MarkdownDocument만 받으므로,
//  AI가 만든 임의 마크다운 문자열을 위한 경량 블록 렌더러를 따로 둔다(헤더/불릿/문단).
//  인라인 강조(**굵게** 등)는 AttributedString(markdown:)로 처리.
//

import SwiftUI
import UIKit

struct AISummaryView: View {
    let title: String
    let markdown: String
    var createdAt: Date? = nil
    var onClose: () -> Void

    @State private var toast: String?

    // Dynamic Type 대응.
    @ScaledMetric(relativeTo: .largeTitle) private var h1Size: CGFloat = 24
    @ScaledMetric(relativeTo: .title3) private var h2Size: CGFloat = 18
    @ScaledMetric(relativeTo: .headline) private var h3Size: CGFloat = 15
    @ScaledMetric(relativeTo: .body) private var bodySize: CGFloat = 15

    private var blocks: [SummaryBlock] { SummaryBlock.parse(markdown) }

    var body: some View {
        ZStack(alignment: .top) {
            Palette.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                navBar
                Divider().overlay(Palette.divider)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        ForEach(blocks) { block in
                            blockView(block)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .padding(.bottom, 60)
                }
            }

            if let toast {
                ToastPill(text: toast)
                    .padding(.top, 64)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Header (제목 + 안내)

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text(title)
                .font(.system(size: h1Size, weight: .heavy, design: .serif))
                .tracking(-0.4)
                .foregroundStyle(Palette.ink)
                .textSelection(.enabled)
            Label("AI가 다시 정리한 내용이에요. 시험 전 원본과 한 번 비교해 주세요.", systemImage: "sparkles")
                .font(.system(size: 11.5))
                .foregroundStyle(Palette.subtle)
                .labelStyle(.titleAndIcon)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, Space.s5)
    }

    // MARK: - Nav

    private var navBar: some View {
        HStack(spacing: 0) {
            Button { onClose() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.brown)
                    .frame(width: 44, height: 44)
            }
            Spacer()
            Text("AI 정리본")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.ink)
            Spacer()
            Button { copy() } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.brown)
                    .frame(width: 40, height: 44)
            }
            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.brown)
                    .frame(width: 40, height: 44)
            }
        }
        .frame(height: 52)
        .padding(.horizontal, 6)
    }

    private var shareText: String { "# \(title)\n\n\(markdown)" }

    private func copy() {
        UIPasteboard.general.string = shareText
        showToast("정리본 복사됨")
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func showToast(_ t: String) {
        withAnimation(.easeOut(duration: 0.15)) { toast = t }
        Task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.15)) { if toast == t { toast = nil } }
            }
        }
    }

    // MARK: - Block render

    @ViewBuilder
    private func blockView(_ block: SummaryBlock) -> some View {
        switch block.kind {
        case let .heading(level, text, warn):
            headingView(level: level, text: text, warn: warn)
        case let .bullet(text, indent, marker):
            bulletView(text: text, indent: indent, marker: marker)
        case let .paragraph(text):
            Text(inline(text))
                .font(.system(size: bodySize))
                .lineSpacing(3)
                .foregroundStyle(Palette.ink2)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 3)
        }
    }

    private func headingView(level: Int, text: String, warn: Bool) -> some View {
        let size = level == 1 ? h1Size : (level == 2 ? h2Size : h3Size)
        let weight: Font.Weight = level >= 3 ? .semibold : (level == 2 ? .bold : .heavy)
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            if warn {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: size * 0.72))
                    .foregroundStyle(Palette.Highlight.orange)
            }
            Text(text)
                .font(.system(size: size, weight: weight, design: .serif))
                .tracking(-0.2)
                .foregroundStyle(warn ? Palette.Highlight.orange : Palette.ink)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, level == 1 ? Space.s4 : (level == 2 ? Space.s5 : Space.s3))
        .padding(.bottom, Space.s2)
    }

    private func bulletView(text: String, indent: Int, marker: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(marker)
                .font(.system(size: bodySize, weight: .semibold))
                .foregroundStyle(Palette.brown)
                .frame(minWidth: 13, alignment: .leading)
            Text(inline(text))
                .font(.system(size: bodySize))
                .lineSpacing(3)
                .foregroundStyle(Palette.ink2)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, CGFloat(indent) * 16)
        .padding(.vertical, 3)
    }

    /// 인라인 마크다운(**굵게**, *기울임*, `코드`, [링크])만 해석. 실패하면 평문.
    private func inline(_ s: String) -> AttributedString {
        (try? AttributedString(
            markdown: s,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(s)
    }
}

private struct ToastPill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Palette.cream)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(Capsule().fill(Palette.ink))
            .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 6)
    }
}

// MARK: - 경량 마크다운 블록 파서

struct SummaryBlock: Identifiable {
    let id: Int
    let kind: Kind

    enum Kind {
        case heading(level: Int, text: String, warn: Bool)
        case bullet(text: String, indent: Int, marker: String)
        case paragraph(text: String)
    }

    /// AI 정리본 마크다운(헤더 #/##/###, 불릿 -/*/+, 번호목록, 문단)을 블록으로 분해.
    /// 코드펜스·표 등 미지원 문법은 문단으로 폴백한다.
    static func parse(_ md: String) -> [SummaryBlock] {
        var out: [SummaryBlock] = []
        for raw in md.components(separatedBy: "\n") {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed == "---" || trimmed == "***" || trimmed == "___" { continue }   // 수평선 무시

            let kind: Kind
            if trimmed.hasPrefix("#### ") {
                kind = .heading(level: 3, text: String(trimmed.dropFirst(5)), warn: false)
            } else if trimmed.hasPrefix("### ") {
                kind = .heading(level: 3, text: String(trimmed.dropFirst(4)), warn: false)
            } else if trimmed.hasPrefix("## ") {
                let t = String(trimmed.dropFirst(3))
                kind = .heading(level: 2, text: t, warn: t.contains("확인 필요"))
            } else if trimmed.hasPrefix("# ") {
                kind = .heading(level: 1, text: String(trimmed.dropFirst(2)), warn: false)
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                kind = .bullet(text: String(trimmed.dropFirst(2)),
                               indent: indentLevel(raw), marker: "•")
            } else if let (num, rest) = orderedItem(trimmed) {
                kind = .bullet(text: rest, indent: indentLevel(raw), marker: "\(num).")
            } else {
                kind = .paragraph(text: trimmed)
            }
            out.append(SummaryBlock(id: out.count, kind: kind))
        }
        return out
    }

    private static func indentLevel(_ raw: String) -> Int {
        let leading = raw.prefix { $0 == " " || $0 == "\t" }.count
        return min(leading / 2, 3)
    }

    /// "12. 본문" → (12, "본문"). 아니면 nil.
    private static func orderedItem(_ s: String) -> (Int, String)? {
        var digits = ""
        var idx = s.startIndex
        while idx < s.endIndex, s[idx].isNumber { digits.append(s[idx]); idx = s.index(after: idx) }
        guard !digits.isEmpty, let n = Int(digits), idx < s.endIndex, s[idx] == "." else { return nil }
        let after = s.index(after: idx)
        guard after < s.endIndex, s[after] == " " else { return nil }
        return (n, String(s[s.index(after: after)...]))
    }
}

#Preview("AI 정리본") {
    AISummaryView(
        title: "항생제의 작용 기전",
        markdown: """
        ## 항생제란
        - **항생제**: 세균을 죽이거나 증식을 막는 약물.
        - 바이러스에는 듣지 않음(세균 ≠ 바이러스).

        ## 작용 방식
        1. 세포벽 합성 억제 — 예: 페니실린.
        2. 단백질 합성 억제 — 예: 테트라사이클린.

        ## 확인 필요
        - 내성 발생 기전의 구체적 수치는 노트에 근거가 불분명함.
        """,
        onClose: {}
    )
}
