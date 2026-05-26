//
//  PDFFauxView.swift
//  Lumark
//
//  ResultView "원본 PDF" 탭 — 디자인 단계용 faux 페이퍼.
//  실제 PDFKit 연결(Day 8+)에서 PDFKitView로 교체되고,
//  형광펜 오버레이는 ZStack { PDFKitView; HighlightOverlays }로 분리될 예정.
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
                totalPages: document.pageCount,
                title: document.title
            ) {
                Text("1. 항생제의 분류")
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .padding(.top, 14)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(Palette.ink)

                paragraph {
                    [
                        .highlight("베타락탐계는 세포벽 합성을 억제", .yellow),
                        .plain("하는 대표적인 항생제이며, 페니실린·세팔로스포린·카바페넴이 포함된다. "),
                        .highlight("페니실린 알레르기 환자에서", .yellow),
                        .plain(" 교차반응 가능성을 항상 확인한다."),
                    ]
                }

                paragraph {
                    [
                        .highlight("세팔로스포린은 1~5세대까지 분류", .orange),
                        .plain("되며, 세대가 올라갈수록 그람음성 균에 대한 활성이 증가한다."),
                    ]
                }

                Text("2. 부작용 모니터링")
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .padding(.top, 14)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(Palette.ink)

                paragraph {
                    [
                        .plain("신독성 신호로 "),
                        .highlight("BUN/Cr 상승", .yellow),
                        .plain("을 추적하고, "),
                        .highlight("청신경 독성은 대부분 가역적", .pink),
                        .plain("이지만 조기 발견이 중요하다."),
                    ]
                }

                paragraph {
                    [
                        .highlight("위막성 대장염", .pink),
                        .plain("은 클로스트리디움 디피실에 의해 발생하며, 광범위 항생제 사용 후 발생한 설사에서 의심해야 한다."),
                    ]
                }

                paragraph {
                    [
                        .highlight("감수성 검사(AST) 결과가 우선", .blue),
                        .plain("하며, 경험적 치료는 그 다음이다."),
                    ]
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
