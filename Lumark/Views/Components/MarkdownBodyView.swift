//
//  MarkdownBodyView.swift
//  Lumark
//
//  ResultView "마크다운" 탭. 디자인: ResultView.html .rv-body의 md-* 클래스들.
//
//  핵심 디자인:
//    - 글머리표는 디스크 대신 좌측 컬러바 (Rectangle width 2)
//    - 필터 OFF 색은 숨기지 말고 opacity 0.28로 dim
//    - 헤더는 Nanum Myeongjo (serif fallback) 800/700
//

import SwiftUI

struct MarkdownBodyView: View {
    let document: MarkdownDocument
    /// 색별 ON/OFF 상태. true = 보임, false = dim
    let chips: [ColorCategory: Bool]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // H1 — 노트 제목
            Text(document.title)
                .font(.system(size: 26, weight: .heavy, design: .serif))
                .tracking(-0.4)
                .foregroundStyle(Palette.ink)
                .textSelection(.enabled)
                .padding(.top, Space.s2)
                .padding(.bottom, Space.s5)

            // 본문 섹션들
            ForEach(document.sections) { section in
                if let title = section.title {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(title)
                            .font(.system(size: 18, weight: .bold, design: .serif))
                            .tracking(-0.2)
                            .foregroundStyle(Palette.ink)
                            .textSelection(.enabled)
                        if section.pageNumber > 0 {
                            Text("p. \(section.pageNumber)")
                                .font(Typo.monoSm)
                                .foregroundStyle(Palette.muted)
                        }
                    }
                    .padding(.top, Space.s5)
                    .padding(.bottom, Space.s2)
                } else if !section.items.isEmpty {
                    // 제목 없는 첫 섹션
                    Text("(주제 미지정)")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(Palette.subtle)
                        .padding(.top, Space.s5)
                        .padding(.bottom, Space.s2)
                }

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(section.items) { item in
                        bulletRow(item)
                    }
                }
                .padding(.bottom, Space.s3)
            }
        }
    }

    // MARK: - bullet row

    private func bulletRow(_ item: MarkdownItem) -> some View {
        let on = chips[item.color] ?? true

        return HStack(alignment: .top, spacing: 0) {
            // 좌측 컬러바 (디자인 시안 핵심)
            Rectangle()
                .fill(item.color.swatch)
                .frame(width: 2)
                .padding(.vertical, 9)
                .opacity(on ? 1.0 : 0.35)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.text)
                    .font(.system(size: 14))
                    .lineSpacing(2)
                    .foregroundStyle(Palette.ink2)
                    .textSelection(.enabled)

                if item.pageNumber > 0 {
                    Text("p. \(item.pageNumber)")
                        .font(Typo.monoSm)
                        .foregroundStyle(Palette.muted)
                }
            }
            .padding(.leading, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .opacity(on ? 1.0 : 0.28)
        .animation(.easeInOut(duration: 0.15), value: on)
    }

}
