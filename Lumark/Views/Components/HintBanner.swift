//
//  HintBanner.swift
//  Lumark
//
//  HomeView 안내 배너 — "굿노트에서 공유로 보내면 자동으로 받아요"
//

import SwiftUI

struct HintBanner: View {
    var body: some View {
        HStack(spacing: Space.s3) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Palette.brass.opacity(0.12))
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.brass)
            }
            .frame(width: 32, height: 32)

            // Text 인터폴레이션 (iOS 26+ 권장 패턴): AttributedString 인라인 합성
            Text(hintAttributed)
                .font(.system(size: 12.5))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(Palette.hairline)
        )
    }

    /// "굿노트에서 공유" 부분만 강조한 attributed 인라인.
    private var hintAttributed: AttributedString {
        var head = AttributedString("굿노트에서 공유")
        head.font = .system(size: 12.5, weight: .semibold)
        head.foregroundColor = Palette.ink

        var tail = AttributedString(" → Lumark로 보내면 자동으로 받아요")
        tail.foregroundColor = Palette.ink2

        return head + tail
    }
}
