//
//  MyQuizzesView.swift
//  Lumark
//
//  만든 퀴즈(플래시카드) 모아보기. 카드가 1장 이상 있는 노트만 나열.
//  행 탭 → 학습(FlashcardStudyView). context menu → 정리본 보기 / 퀴즈 삭제.
//

import SwiftUI
import SwiftData

private enum QuizLibraryTab: String, CaseIterable, Identifiable {
    case quizzes = "퀴즈"
    case unknown = "모르는 카드"

    var id: String { rawValue }
}

struct MyQuizzesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @Query(sort: \Flashcard.createdAt, order: .reverse) private var flashcards: [Flashcard]

    /// 행에서 "정리본 보기"를 누르면 호출 — HomeView가 결과 화면으로 push.
    var onOpenNote: (Note) -> Void

    @State private var studyingNote: Note?
    @State private var deleteTarget: Note?
    @State private var activeError: LumarkError?
    @State private var selectedTab: QuizLibraryTab = .quizzes

    /// 카드가 있는 노트만. @Query가 이미 최신순 정렬.
    private var quizNotes: [Note] {
        notes.filter { !$0.flashcards.isEmpty }
    }

    private var unknownCards: [Flashcard] {
        flashcards.filter { $0.reviewState == .unknown }
    }

    var body: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                tabPicker
                    .padding(.horizontal, Space.s5)
                    .padding(.top, Space.s2)
                    .padding(.bottom, Space.s3)

                switch selectedTab {
                case .quizzes:
                    if quizNotes.isEmpty {
                        emptyState
                    } else {
                        quizListContent
                    }
                case .unknown:
                    if unknownCards.isEmpty {
                        unknownEmptyState
                    } else {
                        unknownListContent
                    }
                }
            }
        }
        .navigationTitle("내 퀴즈")
        .navigationBarTitleDisplayMode(.large)
        .fullScreenCover(item: $studyingNote) { note in
            FlashcardStudyView(
                cards: note.flashcards.sorted { $0.createdAt < $1.createdAt },
                onClose: { studyingNote = nil }
            )
        }
        .alert("이 퀴즈를 삭제할까요?", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("삭제", role: .destructive) {
                if let n = deleteTarget { deleteQuiz(n) }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("\(deleteTarget?.title ?? "")의 카드 \(deleteTarget?.flashcards.count ?? 0)장이 삭제돼요. 정리본은 그대로 남아요.")
        }
        .errorAlert(error: $activeError)
    }

    // MARK: - 목록

    private var tabPicker: some View {
        Picker("퀴즈 보기", selection: $selectedTab) {
            ForEach(QuizLibraryTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    private var quizListContent: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(quizNotes) { row(for: $0) }
            }
            .padding(.horizontal, Space.s5)
            .padding(.top, Space.s3)
            .padding(.bottom, Space.s7)
        }
    }

    private var unknownListContent: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(unknownCards) { card in
                    unknownRow(for: card)
                }
            }
            .padding(.horizontal, Space.s5)
            .padding(.top, Space.s3)
            .padding(.bottom, Space.s7)
        }
    }

    private func row(for note: Note) -> some View {
        Button {
            studyingNote = note
        } label: {
            HStack(spacing: Space.s3) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Palette.Highlight.yellowBG)
                    Image(systemName: "rectangle.stack.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Palette.brown)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(note.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Text("\(note.flashcards.count)개 카드 · \(koreanDate(note.createdAt))")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.subtle)
                    if let preview = firstQuestion(note) {
                        Text(preview)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Palette.muted)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Palette.brown)
            }
            .padding(Space.s3)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Palette.divider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(note.title), 카드 \(note.flashcards.count)개")
        .accessibilityHint("두 번 탭하면 학습 시작")
        .contextMenu {
            Button {
                onOpenNote(note)
            } label: {
                Label("정리본 보기", systemImage: "doc.text")
            }
            Button(role: .destructive) {
                deleteTarget = note
            } label: {
                Label("퀴즈 삭제", systemImage: "trash")
            }
        }
    }

    private func unknownRow(for card: Flashcard) -> some View {
        HStack(alignment: .top, spacing: Space.s3) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Palette.Highlight.orangeBG)
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Palette.brown)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 6) {
                if let title = card.note?.title {
                    Text(title)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                }

                Text(card.question)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)

                Text(card.answer)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Palette.subtle)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button {
                markKnown(card)
            } label: {
                Label("안다", systemImage: "checkmark")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Palette.cream)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Palette.brown))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("안다로 바꾸기")
        }
        .padding(Space.s3)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Palette.divider, lineWidth: 1)
        )
    }

    // MARK: - 빈 상태

    private var emptyState: some View {
        VStack(spacing: Space.s3) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Palette.muted)
            Text("아직 만든 퀴즈가 없어요")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.ink)
            Text("정리본을 연 다음 아래쪽 \"퀴즈 만들기\"를 누르면\n여기에 카드가 모여요.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.subtle)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Space.s5)
        .padding(.bottom, Space.s7)
    }

    private var unknownEmptyState: some View {
        VStack(spacing: Space.s3) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Palette.muted)
            Text("모르는 카드가 없어요")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.ink)
            Text("학습 중 \"모르겠어\"로 표시한 카드가\n여기에 모여요.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.subtle)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Space.s5)
        .padding(.bottom, Space.s7)
    }

    // MARK: - 포맷

    private func koreanDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f.string(from: date)
    }

    private func firstQuestion(_ note: Note) -> String? {
        note.flashcards.sorted { $0.createdAt < $1.createdAt }.first?.question
    }

    // MARK: - 삭제

    /// 노트의 플래시카드만 삭제(정리본 Note는 유지).
    private func deleteQuiz(_ note: Note) {
        for card in note.flashcards { modelContext.delete(card) }
        do {
            try modelContext.save()
        } catch {
            activeError = .wrapped(code: "QUIZ-DEL", message: "퀴즈 삭제 실패: \(error.localizedDescription)")
        }
    }

    private func markKnown(_ card: Flashcard) {
        card.reviewState = .known
        do {
            try modelContext.save()
            UISelectionFeedbackGenerator().selectionChanged()
        } catch {
            activeError = .wrapped(code: "QUIZ-KNOWN", message: "카드 상태 저장 실패: \(error.localizedDescription)")
        }
    }
}

#Preview {
    NavigationStack {
        MyQuizzesView { _ in }
    }
    .modelContainer(MockData.previewContainer(withMockNotes: true))
}
