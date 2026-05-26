//
//  ActionCardContent.swift
//  Lumark
//
//  ActionCard의 외형만 빌려쓰는 컨텐츠 뷰. PhotosPicker 같은 Button 기반 컨테이너의
//  label로 넣기 위해 분리 (Button 안에 Button을 못 넣으니까).
//

import SwiftUI

struct ActionCardContent: View {
    let systemImage: String
    let label: String
    let desc: String
    var primary: Bool = false

    var body: some View {
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
}
