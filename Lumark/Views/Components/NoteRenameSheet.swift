//
//  NoteRenameSheet.swift
//  Lumark
//
//  ResultView + RecentNotesView에서 공유하는 이름 변경 시트.
//  중복 코드 제거용.
//

import SwiftUI

struct NoteRenameSheet: View {
    @Binding var title: String
    let onSave: () -> Void
    let onCancel: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.cream.ignoresSafeArea()
                VStack(alignment: .leading, spacing: Space.s4) {
                    Text("노트 이름")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(Palette.brass)

                    TextField("이름", text: $title)
                        .textFieldStyle(.plain)
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(Palette.ink)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .fill(Palette.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .strokeBorder(Palette.divider, lineWidth: 1)
                        )
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit(onSave)

                    Spacer()
                }
                .padding(.horizontal, Space.s5)
                .padding(.top, Space.s4)
            }
            .navigationTitle("이름 변경")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소", action: onCancel)
                        .foregroundStyle(Palette.subtle)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장", action: onSave)
                        .foregroundStyle(Palette.brown)
                        .fontWeight(.semibold)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear { focused = true }
    }
}
