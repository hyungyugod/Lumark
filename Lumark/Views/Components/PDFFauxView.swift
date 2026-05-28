//
//  PDFFauxView.swift
//  Lumark
//
//  ResultView "원본 PDF" 탭 — 페이지 이미지가 없을 때의 폴백 페이퍼.
//  파싱된 MarkdownDocument(섹션·형광펜 항목)를 종이 모양으로 렌더한다.
//  페이지 이미지가 있으면 ResultView가 DetectionOverlayView를 대신 쓴다.
//
//  디자인: ResultView.html .pdf-page + .hl 스팬.
//

import SwiftUI

struct PDFFauxView: View {
    let document: MarkdownDocument
    let chips: [ColorCategory: Bool]

    var body: some View {
        VStack(spacing: Space.s4) {
            page(
                number: 1,
                totalPages: max(1, document.pageCount),
                title: document.title
            ) {
                if document.sections.isEmpty {
                    Text("형광펜으로 표시한 내용이 아직 없어요.")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    ForEach(document.sections) { section in
                        if let title = section.title {
                            Text(title)
                                .font(.system(size: 16, weight: .bold, design: .serif))
                                .padding(.top, 14)
                                .padding(.bottom, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundStyle(Palette.ink)
                        }
                        ForEach(section.items) { item in
                            paragraph { [.highlight(item.text, item.color)] }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 한 페이지

    @ViewBuilder
    private func page<Content: View>(
        number: Int,
        totalPages: Int,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 제목 + 하단 라인
            Text(title)
                .font(.system(size: 22, weight: .heavy, design: .serif))
                .tracking(-0.2)
                .foregroundStyle(Palette.ink)
                .padding(.bottom, 10)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Palette.ink)
                        .frame(height: 1.5)
                }
                .padding(.bottom, 6)

            content()
                .font(.system(size: 13))
                .foregroundStyle(Palette.ink2)
                .lineSpacing(6)

            HStack {
                Spacer()
                Text("p. \(number) / \(totalPages)")
                    .font(Typo.monoSm)
                    .foregroundStyle(Palette.muted)
            }
            .padding(.top, Space.s4)
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 28)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Palette.surface) // paper tone — 실제로는 약간 다른 token
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(Palette.divider, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.18), radius: 30, x: 0, y: 14)
    }

    // MARK: - 인라인 형광펜 텍스트 합성

    /// 한 문단 = plain/highlight 조각들의 시퀀스. AttributedString.backgroundColor로 결합.
    /// (Text + Text는 background 모디파이어를 못 살리기 때문에 AttributedString 경로 사용.)
    private func paragraph(@HLBuilder _ segs: () -> [HLSegment]) -> some View {
        var attr = AttributedString()
        for seg in segs() {
            switch seg {
            case .plain(let s):
                attr.append(AttributedString(s))
            case .highlight(let s, let c):
                let on = chips[c] ?? true
                var part = AttributedString(s)
                if on {
                    // 형광펜 효과: 색상 + 알파. 디자인의 그라디언트 띠 효과는
                    // AttributedString backgroundColor로 흉내내기 어려워 평면 배경으로 근사.
                    part.backgroundColor = c.swatch.opacity(0.45)
                }
                attr.append(part)
            }
        }
        return Text(attr)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 3)
    }

    // MARK: - 세그먼트 타입

    enum HLSegment {
        case plain(String)
        case highlight(String, ColorCategory)
    }

    @resultBuilder
    enum HLBuilder {
        static func buildBlock(_ components: [HLSegment]...) -> [HLSegment] {
            components.flatMap { $0 }
        }
        static func buildExpression(_ expression: [HLSegment]) -> [HLSegment] {
            expression
        }
    }
}
