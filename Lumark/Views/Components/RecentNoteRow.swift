//
//  RecentNoteRow.swift
//  Lumark
//
//  HomeView "최근 작업" 리스트의 한 줄.
//

import SwiftUI

struct RecentNoteRow: View {
    let note: Note

    var body: some View {
        HStack(spacing: 14) {
            // 페이지 수 표시 썸네일
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(
                        colors: [Palette.surface2, Palette.surface],
                        startPoint: .top, endPoint: .bottom
                    ))
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Palette.hairline, lineWidth: 1)
                Text("\(note.pageCount)p")
                    .font(Typo.monoSm)
                    .foregroundStyle(Palette.subtle)
                    .padding(.horizontal, 2)
                    .background(Palette.surface)
            }
            .frame(width: 44, height: 56)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(note.title)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    if note.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Palette.brass)
                    }
                }
                Text(dateSummary)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.subtle)
                colorDots
                    .padding(.top, 4)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.muted)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Palette.divider, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(note.title), \(dateSummary)")
        .accessibilityHint("두 번 탭하여 열기")
    }

    private var dateSummary: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return "\(f.string(from: note.createdAt)) · \(note.pageCount)페이지"
    }

    private var colorDots: some View {
        // 페이지 내 등장한 색 카테고리만 추출
        let categories = Set(note.pages.flatMap { $0.highlights }.map { $0.colorCategory })
        let ordered = ColorCategory.allCases.filter { categories.contains($0) }
        return HStack(spacing: 4) {
            ForEach(ordered) { c in
                Circle()
                    .fill(c.swatch)
                    .frame(width: 7, height: 7)
            }
        }
    }
}
