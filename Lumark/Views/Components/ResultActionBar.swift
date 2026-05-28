//
//  ResultActionBar.swift
//  Lumark
//
//  ResultView 하단 액션 바. [복사][공유][PDF][퀴즈]
//  primary = 퀴즈 (brown 배경 + cream 글자) — 정리본 직후 가장 권하는 동작.
//

import SwiftUI

struct ResultActionBar: View {
    var onCopy: () -> Void
    var onShare: () -> Void
    var onExportPDF: () -> Void
    var quizSystemImage: String
    var quizLabel: String
    var onQuiz: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            actionButton(systemImage: "doc.on.doc", label: "복사", primary: false, action: onCopy)
            actionButton(systemImage: "square.and.arrow.up", label: "공유", primary: false, action: onShare)
            actionButton(systemImage: "doc.richtext", label: "PDF", primary: false, action: onExportPDF)
            actionButton(systemImage: quizSystemImage, label: quizLabel, primary: true, action: onQuiz)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Palette.divider, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 30, x: 0, y: 12)
    }

    private func actionButton(
        systemImage: String,
        label: String,
        primary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(primary ? Palette.cream : Palette.ink2)
                Text(label)
                    .font(.system(size: 10.5, weight: primary ? .semibold : .medium))
                    .foregroundStyle(primary ? Palette.cream : Palette.ink2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(primary ? Palette.brown : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
