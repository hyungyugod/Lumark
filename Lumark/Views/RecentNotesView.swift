//
//  RecentNotesView.swift
//  Lumark
//
//  저장된 노트 전체 목록.
//  검색 / 정렬 / 즐겨찾기 / 컨텍스트 메뉴 (이름변경, 삭제, 즐겨찾기 토글).
//

import SwiftUI
import SwiftData

struct RecentNotesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]

    var onOpenNote: (Note) -> Void

    // 필터/정렬 상태
    @State private var searchText: String = ""
    @State private var sortOption: SortOption = .recent

    @State private var renamingNote: Note?
    @State private var editingTitle: String = ""
    @State private var deleteTarget: Note?
    @State private var activeError: LumarkError?

    enum SortOption: String, CaseIterable, Identifiable {
        case recent = "최근"
        case oldest = "오래된 순"
        case title = "이름"
        case pages = "페이지 수"

        var id: String { rawValue }

        var sfSymbol: String {
            switch self {
            case .recent: return "clock"
            case .oldest: return "clock.arrow.circlepath"
            case .title:  return "textformat"
            case .pages:  return "doc.text"
            }
        }
    }

    var body: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()

            if notes.isEmpty {
                EmptyStateView()
                    .padding(.bottom, Space.s7)
            } else {
                listContent
            }
        }
        .navigationTitle("최근 작업")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "이름 검색")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                sortMenu
            }
        }
        .alert("이 노트를 삭제할까요?", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("삭제", role: .destructive) {
                if let n = deleteTarget { delete(n) }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("\(deleteTarget?.title ?? "") — 되돌릴 수 없어요.")
        }
        .sheet(item: $renamingNote) { note in
            NoteRenameSheet(
                title: $editingTitle,
                onSave: {
                    rename(note, to: editingTitle)
                    renamingNote = nil
                },
                onCancel: { renamingNote = nil }
            )
            .presentationDetents([.height(220)])
        }
        .errorAlert(error: $activeError)
    }

    // MARK: - 목록

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                let (favorites, others) = filteredAndSorted()

                if !favorites.isEmpty {
                    sectionHeader("즐겨찾기")
                    ForEach(favorites) { row(for: $0) }
                }

                if !favorites.isEmpty && !others.isEmpty {
                    sectionHeader("모든 노트")
                }

                if !others.isEmpty {
                    ForEach(others) { row(for: $0) }
                } else if favorites.isEmpty && !searchText.isEmpty {
                    Text("검색 결과가 없어요")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.subtle)
                        .padding(.top, Space.s5)
                }
            }
            .padding(.horizontal, Space.s5)
            .padding(.top, Space.s3)
            .padding(.bottom, Space.s7)
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(Palette.brass)
            Spacer()
        }
        .padding(.top, Space.s2)
        .padding(.bottom, 2)
    }

    private func row(for note: Note) -> some View {
        Button {
            onOpenNote(note)
        } label: {
            RecentNoteRow(note: note)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                toggleFavorite(note)
            } label: {
                Label(
                    note.isFavorite ? "즐겨찾기 해제" : "즐겨찾기",
                    systemImage: note.isFavorite ? "star.slash" : "star"
                )
            }
            Button {
                editingTitle = note.title
                renamingNote = note
            } label: {
                Label("이름 변경", systemImage: "pencil")
            }
            Button(role: .destructive) {
                deleteTarget = note
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                deleteTarget = note
            } label: {
                Label("삭제", systemImage: "trash")
            }
            Button {
                toggleFavorite(note)
            } label: {
                Label(
                    note.isFavorite ? "해제" : "즐겨찾기",
                    systemImage: note.isFavorite ? "star.slash.fill" : "star.fill"
                )
            }
            .tint(.yellow)
        }
    }

    // MARK: - 정렬 메뉴

    private var sortMenu: some View {
        Menu {
            ForEach(SortOption.allCases) { opt in
                Button {
                    sortOption = opt
                } label: {
                    if opt == sortOption {
                        Label(opt.rawValue, systemImage: "checkmark")
                    } else {
                        Label(opt.rawValue, systemImage: opt.sfSymbol)
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .foregroundStyle(Palette.brown)
        }
    }

    // MARK: - 필터링 + 정렬

    private func filteredAndSorted() -> (favorites: [Note], others: [Note]) {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered: [Note] = notes.filter { note in
            q.isEmpty || note.title.lowercased().contains(q)
        }
        let sorted: [Note] = filtered.sorted { lhs, rhs in
            switch sortOption {
            case .recent: return lhs.createdAt > rhs.createdAt
            case .oldest: return lhs.createdAt < rhs.createdAt
            case .title:  return lhs.title.localizedCompare(rhs.title) == .orderedAscending
            case .pages:  return lhs.pageCount > rhs.pageCount
            }
        }
        let favs = sorted.filter { $0.isFavorite }
        let rest = sorted.filter { !$0.isFavorite }
        return (favs, rest)
    }

    // MARK: - CRUD
    //
    // spec §8 "데이터 절대 안 잃음" — save 실패는 silent 처리 금지.
    // ResultView도 같은 패턴(errorAlert)으로 통일.

    private func delete(_ note: Note) {
        modelContext.delete(note)
        do {
            try modelContext.save()
        } catch {
            activeError = .wrapped(code: "DELETE", message: "삭제 실패: \(error.localizedDescription)")
        }
    }

    private func rename(_ note: Note, to newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        note.title = trimmed
        do {
            try modelContext.save()
        } catch {
            activeError = .wrapped(code: "RENAME", message: "이름 변경 실패: \(error.localizedDescription)")
        }
    }

    private func toggleFavorite(_ note: Note) {
        note.isFavorite.toggle()
        do {
            try modelContext.save()
            UISelectionFeedbackGenerator().selectionChanged()
        } catch {
            // 토글은 되돌리고 사용자에게 알림
            note.isFavorite.toggle()
            activeError = .wrapped(code: "FAV", message: "즐겨찾기 저장 실패: \(error.localizedDescription)")
        }
    }
}

#Preview("With notes") {
    NavigationStack {
        RecentNotesView { _ in }
    }
    .modelContainer(MockData.previewContainer(withMockNotes: true))
}

#Preview("Empty") {
    NavigationStack {
        RecentNotesView { _ in }
    }
    .modelContainer(MockData.previewContainer(withMockNotes: false))
}
