//
//  ColorFilterChip.swift
//  Lumark
//
//  ResultView 상단 4색 필터 칩. ON/OFF 토글.
//  디자인: ResultView.html .rv-chip.
//

import SwiftUI

struct ColorFilterChip: View {
    let color: ColorCategory
    let label: String
    let isOn: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 7) {
                Circle()
                    .fill(color.swatch)
                    .frame(width: 9, height: 9)
                    .opacity(isOn ? 1.0 : 0.55)
                    .overlay(
                        Circle()
                            .stroke(color.swatch.opacity(0.28), lineWidth: 2)
                            .scaleEffect(1.6)
                            .opacity(isOn ? 1 : 0)
                    )

                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isOn ? Palette.ink : Palette.subtle)
            }
            .padding(.leading, 11)
            .padding(.trailing, 14)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(isOn ? bg(color) : Color.clear)
            )
            .overlay(
                Capsule()
                    .strokeBorder(isOn ? edge(color) : Palette.divider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "켜짐" : "꺼짐")
        .accessibilityHint("두 번 탭하여 \(isOn ? "끄기" : "켜기")")
        .accessibilityAddTraits(.isButton)
    }

    private func bg(_ c: ColorCategory) -> Color {
        switch c {
        case .yellow: return Palette.Highlight.yellowBG
        case .orange: return Palette.Highlight.orangeBG
        case .pink:   return Palette.Highlight.pinkBG
        case .blue:   return Palette.Highlight.blueBG
        }
    }

    private func edge(_ c: ColorCategory) -> Color {
        switch c {
        case .yellow: return Palette.Highlight.yellowEdge
        case .orange: return Palette.Highlight.orangeEdge
        case .pink:   return Palette.Highlight.pinkEdge
        case .blue:   return Palette.Highlight.blueEdge
        }
    }
}
