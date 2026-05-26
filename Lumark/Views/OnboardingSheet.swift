//
//  OnboardingSheet.swift
//  Lumark
//
//  첫 실행 시 굿노트 공유 방법 안내. UserDefaults "lumark.onboarded" 플래그로 1회만.
//

import SwiftUI

struct OnboardingSheet: View {
    let onDone: () -> Void

    @State private var page = 0

    var body: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 32)

                LumarkWordmark(size: 30)

                Spacer().frame(height: 8)

                Text("형광펜만 그으면,\n정리 노트가 알아서 쌓여요")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.subtle)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                Spacer()

                // 페이지별 컨텐츠
                TabView(selection: $page) {
                    pageView(
                        icon: "highlighter",
                        title: "공부할 때처럼 형광펜만 그으세요",
                        body: "노랑은 핵심, 주황은 주제. 색깔이 곧 분류예요.",
                        accent: ColorCategory.yellow.swatch
                    )
                    .tag(0)

                    pageView(
                        icon: "square.and.arrow.up",
                        title: "굿노트에서 공유 → Lumark",
                        body: "공유 시트에서 Lumark를 선택하면 자동으로 가져와요.\n파일 옮길 필요 없어요.",
                        accent: Palette.brass
                    )
                    .tag(1)

                    pageView(
                        icon: "doc.text",
                        title: "변환된 노트는 라이브러리에",
                        body: "마크다운, PDF로 내보내거나 공유할 수 있어요. 한 학기치가 시험 직전 정리본이 돼요.",
                        accent: ColorCategory.orange.swatch
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: 380)

                // 인디케이터
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? Palette.brown : Palette.divider)
                            .frame(width: i == page ? 22 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: page)
                    }
                }
                .padding(.top, Space.s2)

                Spacer()

                // CTA
                Button {
                    if page < 2 {
                        withAnimation { page += 1 }
                    } else {
                        markOnboarded()
                        onDone()
                    }
                } label: {
                    Text(page < 2 ? "다음" : "시작하기")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.cream)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .fill(Palette.brown)
                        )
                }
                .padding(.horizontal, Space.s5)

                // skip
                Button {
                    markOnboarded()
                    onDone()
                } label: {
                    Text("건너뛰기")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.subtle)
                        .padding(.vertical, 12)
                }
                .padding(.bottom, Space.s4)
            }
        }
        .interactiveDismissDisabled()
    }

    private func pageView(icon: String, title: String, body: String, accent: Color) -> some View {
        VStack(spacing: Space.s4) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.16))
                    .frame(width: 96, height: 96)
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(accent)
            }

            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)

                Text(body)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, Space.s5)
            }
        }
        .padding(.vertical, Space.s5)
    }

    private func markOnboarded() {
        UserDefaults.standard.set(true, forKey: "lumark.onboarded")
    }
}

extension UserDefaults {
    var hasOnboarded: Bool { bool(forKey: "lumark.onboarded") }
}

#Preview {
    OnboardingSheet(onDone: {})
}
