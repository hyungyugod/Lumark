//
//  AppIconView.swift
//  Lumark
//
//  앱 아이콘 — 방향 B (펜 끝 + 4색 스트로크).
//  디자인: Lumark_design/logo-icons.jsx IconB.
//
//  이 SwiftUI 뷰는 인앱에는 표시되지 않고, PNG 생성 스크립트
//  (scripts/generate-app-icon.swift)와 코드 형상이 일치하도록
//  레퍼런스 + Preview 검증 용도로만 둠.
//

import SwiftUI

struct AppIconView: View {
    /// 1024 기준으로 만들어진 디자인을 임의 크기로 스케일.
    var size: CGFloat = 1024

    private var s: CGFloat { size / 1024 }

    var body: some View {
        ZStack {
            // 1) 갈색 그라디언트 배경 (가죽 위 빛 반사 느낌)
            LinearGradient(
                stops: [
                    .init(color: Color(oklchL: 0.46, C: 0.062, h: 60), location: 0.0),
                    .init(color: Color(oklchL: 0.40, C: 0.058, h: 56), location: 0.55),
                    .init(color: Color(oklchL: 0.30, C: 0.050, h: 54), location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // sheen (대각선 광택)
            LinearGradient(
                stops: [
                    .init(color: Color(red: 1, green: 240/255, blue: 210/255).opacity(0.10), location: 0.0),
                    .init(color: Color(red: 1, green: 240/255, blue: 210/255).opacity(0),    location: 0.60),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 2) 4색 스트로크 — 펜 끝에서 우하향으로 부채꼴
            strokes
                .offset(x: 228 * s - 512 * s, y: 540 * s - 512 * s)
                .rotationEffect(.degrees(-22), anchor: .topLeading)

            // 3) 펜 몸체 + 황동 링 + chisel tip
            penBody
                .offset(x: 256 * s - 512 * s, y: 564 * s - 512 * s)
                .rotationEffect(.degrees(-22), anchor: .topLeading)
        }
        .frame(width: size, height: size)
        .clipped()
    }

    // MARK: - 스트로크

    private var strokes: some View {
        ZStack(alignment: .topLeading) {
            stroke(color: ColorCategory.yellow.swatch, x: 0,   y: 0,   w: 600)
            stroke(color: ColorCategory.orange.swatch, x: 40,  y: 78,  w: 520)
            stroke(color: ColorCategory.pink.swatch,   x: 80,  y: 156, w: 440)
            stroke(color: ColorCategory.blue.swatch,   x: 120, y: 234, w: 360)
        }
        .opacity(0.95)
    }

    private func stroke(color: Color, x: CGFloat, y: CGFloat, w: CGFloat) -> some View {
        Capsule()
            .fill(color)
            .frame(width: w * s, height: 42 * s)
            .offset(x: x * s, y: y * s)
    }

    // MARK: - 펜 몸체

    private var penBody: some View {
        ZStack(alignment: .topLeading) {
            // 그림자
            RoundedRectangle(cornerRadius: 14 * s, style: .continuous)
                .fill(Color.black.opacity(0.18))
                .frame(width: 92 * s, height: 320 * s)
                .offset(x: (-46 + 8) * s, y: (-28 + 6) * s)

            // 바디 (ivory)
            RoundedRectangle(cornerRadius: 12 * s, style: .continuous)
                .fill(Color(oklchL: 0.94, C: 0.018, h: 82))
                .frame(width: 84 * s, height: 280 * s)
                .offset(x: -42 * s, y: -260 * s)

            // 황동 링
            Rectangle()
                .fill(Color(oklchL: 0.70, C: 0.10, h: 78))
                .frame(width: 84 * s, height: 14 * s)
                .offset(x: -42 * s, y: -30 * s)

            // chisel tip (어두운 평행사변형)
            ChiselTip()
                .fill(Color(oklchL: 0.30, C: 0.04, h: 54))
                .frame(width: 122 * s, height: 72 * s)
                .offset(x: -42 * s, y: -16 * s)

            // tip 위쪽 하이라이트
            ChiselTipHighlight()
                .fill(Color.white.opacity(0.20))
                .frame(width: 84 * s, height: 14 * s)
                .offset(x: -42 * s, y: -16 * s)
        }
    }
}

// MARK: - 펜촉 모양

private struct ChiselTip: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // 원본 path: M -42 -16 L 42 -16 L 80 56 L -2 56 Z (rect 기준 폭 122 = 80 - (-42))
        // rect.width = 122, rect.height = 72, anchor top-left
        let w = rect.width
        let h = rect.height
        // 비율: 좌상=(0,0), 우상=(84/122, 0), 우하=(w, h), 좌하=(40/122 * w, h)
        let p1 = CGPoint(x: 0, y: 0)
        let p2 = CGPoint(x: 84.0 / 122 * w, y: 0)
        let p3 = CGPoint(x: w, y: h)
        let p4 = CGPoint(x: 40.0 / 122 * w, y: h)
        p.move(to: p1)
        p.addLine(to: p2)
        p.addLine(to: p3)
        p.addLine(to: p4)
        p.closeSubpath()
        return p
    }
}

private struct ChiselTipHighlight: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // 원본: M -42 -16 L 42 -16 L 30 -2 L -34 -2 Z
        // rect.width = 84, rect.height = 14
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: w, y: 0))
        p.addLine(to: CGPoint(x: 72.0 / 84 * w, y: h))
        p.addLine(to: CGPoint(x: 8.0 / 84 * w, y: h))
        p.closeSubpath()
        return p
    }
}

#Preview("1024") {
    AppIconView(size: 256)
        .clipShape(RoundedRectangle(cornerRadius: 56))
        .padding()
        .background(Palette.surface2)
}

#Preview("Multiple sizes") {
    HStack(spacing: 20) {
        AppIconView(size: 60)
            .clipShape(RoundedRectangle(cornerRadius: 13))
        AppIconView(size: 120)
            .clipShape(RoundedRectangle(cornerRadius: 27))
        AppIconView(size: 180)
            .clipShape(RoundedRectangle(cornerRadius: 40))
    }
    .padding()
    .background(Palette.cream)
}
