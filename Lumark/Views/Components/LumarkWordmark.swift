//
//  LumarkWordmark.swift
//  Lumark
//
//  "Lumark" 워드마크 — Nanum Myeongjo(또는 .serif fallback) 800 weight에
//  'm' 위 brass dot + 'k' 하단 미세 hairline 두 가지 flourish가 붙는다.
//  디자인: Lumark_design/logo-icons.jsx <Wordmark/>.
//
//  앱 아이콘 방향(A/B/C)과 워드마크는 별개 — 워드마크는 인앱 헤더용으로 항상 동일.
//

import SwiftUI

struct LumarkWordmark: View {
    enum Tone { case ink, cream }

    var size: CGFloat = 30
    var tone: Tone = .ink

    var body: some View {
        // 폰트 사이즈에 비례한 휴리스틱 오프셋 (logo-icons.jsx와 동일 비율)
        let dotSize = size * 0.085          // 약 2.5pt @ size=30
        let dotLeft = size * 1.18           // 'm' 첫 arch 위치
        let dotTop  = -size * 0.05

        let flourishWidth = size * 0.30
        let flourishLeft  = size * 2.65
        let flourishBottom = size * 0.10

        ZStack(alignment: .topLeading) {
            Text("Lumark")
                .font(.system(size: size, weight: .heavy, design: .serif))
                .tracking(-size * 0.025)
                .foregroundStyle(tone == .ink ? Palette.ink : Palette.cream)

            // m 위 brass dot
            Circle()
                .fill(Palette.brass)
                .frame(width: dotSize, height: dotSize)
                .offset(x: dotLeft, y: dotTop)

            // k 하단 hairline (오른쪽으로 살짝 기울인 막대)
            Rectangle()
                .fill(Palette.brass)
                .frame(width: flourishWidth, height: max(1.2, size * 0.035))
                .rotationEffect(.degrees(-12), anchor: .leading)
                .offset(x: flourishLeft, y: size - flourishBottom)
        }
        .fixedSize()
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 24) {
        LumarkWordmark(size: 30)
        LumarkWordmark(size: 44)
        LumarkWordmark(size: 64)
        LumarkWordmark(size: 30, tone: .cream)
            .padding()
            .background(Palette.brown)
    }
    .padding()
    .background(Palette.cream)
}
