//
//  ActionCard.swift
//  Lumark
//
//  HomeView의 2×2 그리드용 액션 카드.
//

import SwiftUI

struct ActionCard: View {
    let systemImage: String
    let label: String
    let desc: String
    var primary: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Space.s4) {
                Image(systemName: systemImage)
                    .font(.system(size: 32, weight: .regular))
                    .foregroundStyle(primary ? Palette.cream : Palette.brown)
                    .frame(width: 36, height: 36, alignment: .leading)

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(primary ? Palette.cream : Palette.ink)
                    Text(desc)
                        .font(Typo.caption)
                        .foregroundStyle(primary ? Palette.cream.opacity(0.75) : Palette.subtle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .aspectRatio(1/1.05, contentMode: .fit)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(primary ? Palette.brown : Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(primary ? Palette.brown2 : Palette.divider, lineWidth: 1)
            )
            .cardShadow()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label). \(desc)")
        .accessibilityAddTraits(.isButton)
    }
}
