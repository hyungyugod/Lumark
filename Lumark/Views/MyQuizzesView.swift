//
//  MyQuizzesView.swift
//  Lumark
//
//  만든 퀴즈(플래시카드) 모아보기. 카드가 1장 이상 있는 노트만 나열.
//  행 탭 → 학습(FlashcardStudyView). context menu → 정리본 보기 / 퀴즈 삭제.
//  '모르는 카드' 탭은 카드 한 장씩 복습 — "다음" / "이젠 알아요"(목록에서 제거).
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
    /// 모르는 카드 복습 시 현재 카드 위치. 카드를 익히면 목록이 줄어드는데,
    /// 렌더에서 항상 clamp하므로 같은 위치가 자연스럽게 다음 카드를 가리킨다.
    @State private var unknownIndex = 0

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
                        unknownReviewContent
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

    // MARK: - 모르는 카드 복습

    private var unknownReviewContent: some View {
        let count = unknownCards.count
        let safe = max(0, min(unknownIndex, count - 1))
        let card = unknownCards[safe]
        return VStack(spacing: Space.s4) {
            Text("\(safe + 1) / \(count)")
                .font(Typo.mono)
                .foregroundStyle(Palette.subtle)
                .padding(.top, Space.s2)

            ReviewCardView(card: card)
                .padding(.horizontal, Space.s5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Button { nextUnknown() } label: {
                        Text("다음")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.brown)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.surface))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.brown.opacity(0.35), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(count <= 1)
                    .opacity(count <= 1 ? 0.5 : 1)

                    Button { markKnownReview(card) } label: {
                        Text("이젠 알아요")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.cream)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.brown))
                    }
                    .buttonStyle(.plain)
                }
                Text("‘이젠 알아요’를 누르면 이 카드는 목록에서 사라져요")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.subtle)
            }
            .padding(.horizontal, Space.s5)
            .padding(.bottom, Space.s5)
        }
    }

    /// 다음 모르는 카드로(끝까지 가면 처음으로 순환).
    private func nextUnknown() {
        let count = unknownCards.count
        guard count > 1 else { return }
        unknownIndex = (max(0, min(unknownIndex, count - 1)) + 1) % count
        UISelectionFeedbackGenerator().selectionChanged()
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

    // MARK: - 동작

    /// 노트의 플래시카드만 삭제(정리본 Note는 유지).
    private func deleteQuiz(_ note: Note) {
        for card in note.flashcards { modelContext.delete(card) }
        do {
            try modelContext.save()
        } catch {
            activeError = .wrapped(code: "QUIZ-DEL", message: "퀴즈 삭제 실패: \(error.localizedDescription)")
        }
    }

    /// '이젠 알아요' — 카드를 익힘으로 표시해 모르는 목록에서 제거.
    /// 카드 자체는 원래 퀴즈에 그대로 보존된다(영구 삭제 아님).
    private func markKnownReview(_ card: Flashcard) {
        card.reviewState = .known
        do {
            try modelContext.save()
            UISelectionFeedbackGenerator().selectionChanged()
        } catch {
            activeError = .wrapped(code: "CARD-KNOWN", message: "카드 상태 저장 실패: \(error.localizedDescription)")
        }
    }
}

// MARK: - 모르는 카드 복습용 한 장 (탭하면 질문↔정답)

private struct ReviewCardView: View {
    let card: Flashcard
    @State private var showAnswer = false
    @ScaledMetric(relativeTo: .title2) private var cardTextSize: CGFloat = 20

    /// 정답 면 텍스트. OX 카드면 정답(O/X) + 해설을 함께.
    private var answerText: String {
        if card.kind == .ox, let ox = card.oxAnswer {
            let mark = ox ? "O (참)" : "X (거짓)"
            let exp = card.answer.trimmingCharacters(in: .whitespacesAndNewlines)
            return exp.isEmpty ? "정답: \(mark)" : "정답: \(mark)\n\(exp)"
        }
        return card.answer
    }

    var body: some View {
        VStack(spacing: Space.s4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(showAnswer ? Palette.Highlight.orange : Palette.Highlight.yellow)
                    .frame(width: 8, height: 8)
                Text(showAnswer ? "정답" : "질문")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(Palette.subtle)
            }

            if let title = card.note?.title {
                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
            }

            Spacer()

            Text(showAnswer ? answerText : card.question)
                .font(.system(size: cardTextSize, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, Space.s4)
                .textSelection(.enabled)

            Spacer()

            Text(showAnswer ? "탭하면 질문" : "탭하면 정답")
                .font(.system(size: 11.5))
                .foregroundStyle(Palette.muted)
        }
        .padding(Space.s5)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Palette.divider, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.10), radius: 18, x: 0, y: 8)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) { showAnswer.toggle() }
            UISelectionFeedbackGenerator().selectionChanged()
        }
        .id(card.id)
    }
}

#Preview {
    NavigationStack {
        MyQuizzesView { _ in }
    }
    .modelContainer(MockData.previewContainer(withMockNotes: true))
}
