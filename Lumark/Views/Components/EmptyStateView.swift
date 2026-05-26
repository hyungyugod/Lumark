//
//  EmptyStateView.swift
//  Lumark
//
//  HomeView 빈 상태 — "아직 변환한 노트가 없어요"
//  디자인 시안의 노트북 + 형광펜 라인 아트를 SwiftUI Path로 정확히 옮김.
//  원본: home-screen.jsx EmptyArt.
//

import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: Space.s3) {
            EmptyArtIllustration()
                .stroke(Palette.brown.opacity(0.95), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                .frame(width: 180, height: 126)
                .padding(.bottom, Space.s2)

            Text("아직 변환한 노트가 없어요")
                .font(.system(size: 19, weight: .bold, design: .serif))
                .foregroundStyle(Palette.ink)

            Text("굿노트 PDF를 공유로 보내거나\n업로드 버튼을 눌러 시작해보세요")
                .font(Typo.bodySm)
                .foregroundStyle(Palette.subtle)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: 240)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.s7)
    }
}

/// home-screen.jsx EmptyArt (200×140 viewBox)의 정확한 라인 아트.
private struct EmptyArtIllustration: Shape {
    func path(in rect: CGRect) -> Path {
        // viewBox 200x140 → rect로 스케일
        let sx = rect.width / 200
        let sy = rect.height / 140
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * sx, y: y * sy)
        }

        var path = Path()

        // 노트북 외곽 (32, 22) ~ (148, 122), rx=5
        path.addRoundedRect(
            in: CGRect(x: 32 * sx, y: 22 * sy, width: 116 * sx, height: 100 * sy),
            cornerSize: CGSize(width: 5 * sx, height: 5 * sy)
        )

        // 스파이럴 바인딩 세로선 x=40
        path.move(to: p(40, 22))
        path.addLine(to: p(40, 122))

        // 바인딩 링 6개
        let ringYs: [CGFloat] = [34, 50, 66, 82, 98, 114]
        for y in ringYs {
            path.addEllipse(in: CGRect(
                x: (40 - 2.2) * sx,
                y: (y - 2.2) * sy,
                width: 4.4 * sx,
                height: 4.4 * sy
            ))
        }

        // 글 줄 3개 (opacity는 fill로 못 표현 — strokeBorder 두 단계로 처리 어려움.
        // 라인 아트는 단일 stroke이므로 작은 strokeWidth로 흐릿하게)
        path.move(to: p(56, 46)); path.addLine(to: p(138, 46))
        path.move(to: p(56, 60)); path.addLine(to: p(124, 60))
        path.move(to: p(56, 74)); path.addLine(to: p(132, 74))

        // 형광펜 — translate(118, 78) rotate(28°)
        let penTranslate = CGAffineTransform(translationX: 118 * sx, y: 78 * sy)
        let penRotate = CGAffineTransform(rotationAngle: 28 * .pi / 180)
        let penTransform = penRotate.concatenating(penTranslate)

        // 펜 몸체 (0, 0, 74, 16) rx=3
        var penBody = Path()
        penBody.addRoundedRect(
            in: CGRect(x: 0, y: 0, width: 74 * sx, height: 16 * sy),
            cornerSize: CGSize(width: 3 * sx, height: 3 * sy)
        )
        path.addPath(penBody, transform: penTransform)

        // 펜 캡 분리선 (rect 62, 0, 12, 16)
        var penCap = Path()
        penCap.addRect(CGRect(x: 62 * sx, y: 0, width: 12 * sx, height: 16 * sy))
        path.addPath(penCap, transform: penTransform)

        // chisel tip — M 74 0 L 92 4 L 92 12 L 74 16 Z
        var tip = Path()
        tip.move(to: CGPoint(x: 74 * sx, y: 0))
        tip.addLine(to: CGPoint(x: 92 * sx, y: 4 * sy))
        tip.addLine(to: CGPoint(x: 92 * sx, y: 12 * sy))
        tip.addLine(to: CGPoint(x: 74 * sx, y: 16 * sy))
        tip.closeSubpath()
        path.addPath(tip, transform: penTransform)

        // cap 안쪽 라인 (x=8, y=0 → y=16)
        var capLine = Path()
        capLine.move(to: CGPoint(x: 8 * sx, y: 0))
        capLine.addLine(to: CGPoint(x: 8 * sx, y: 16 * sy))
        path.addPath(capLine, transform: penTransform)

        return path
    }
}

#Preview {
    EmptyStateView()
        .background(Palette.cream)
}
