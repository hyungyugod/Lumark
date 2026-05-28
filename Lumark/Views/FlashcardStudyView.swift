//
//  FlashcardStudyView.swift
//  Lumark
//
//  플래시카드 학습. 탭하면 질문↔정답 뒤집기. 정답을 본 뒤 "알아/모르겠어"로 채점하고,
//  모든 카드를 채점하면 완료 화면(모르는 것만 다시 / 처음부터 / 닫기).
//  (간격반복 SRS는 v0.2 백로그.)
//

import SwiftUI

struct FlashcardStudyView: View {
    let cards: [Flashcard]
    var onClose: () -> Void

    /// 이번 라운드 카드들. "모르는 것만 다시"에서 부분집합으로 교체됨.
    @State private var session: [Flashcard] = []
    @State private var index = 0
    /// cardID → 알아(true) / 모르겠어(false)
    @State private var marks: [UUID: Bool] = [:]
    @State private var showSummary = false

    var body: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                mainContent
            }
        }
        .onAppear { if session.isEmpty { session = cards } }
    }

    @ViewBuilder
    private var mainContent: some View {
        if session.isEmpty {
            emptyState
        } else if showSummary {
            summary
        } else {
            cardPager
            hint
                .padding(.bottom, Space.s4)
        }
    }

    private var summary: some View {
        let onReview: (() -> Void)?
        if unknownCount > 0 {
            onReview = restartUnknown
        } else {
            onReview = nil
        }
        return SummaryView(
            total: session.count,
            known: knownCount,
            unknown: unknownCount,
            onReviewUnknown: onReview,
            onRestartAll: restartAll,
            onClose: onClose
        )
    }

    private var cardPager: some View {
        TabView(selection: $index) {
            ForEach(Array(session.enumerated()), id: \.offset) { i, card in
                FlipCard(card: card, mark: marks[card.id]) { known in
                    mark(card, known: known)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 4)
                .tag(i)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private var knownCount: Int { marks.values.filter { $0 }.count }
    private var unknownCount: Int { marks.values.filter { !$0 }.count }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { onClose() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.brown)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            if !session.isEmpty && !showSummary {
                Text("\(min(index + 1, session.count)) / \(session.count)")
                    .font(Typo.mono)
                    .foregroundStyle(Palette.ink2)
            }

            Spacer()

            Button { shuffle() } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(session.count > 1 && !showSummary ? Palette.brown : Palette.muted)
                    .frame(width: 44, height: 44)
            }
            .disabled(session.count <= 1 || showSummary)
        }
        .padding(.horizontal, 6)
        .frame(height: 52)
    }

    private var hint: some View {
        Text("카드를 탭해 정답을 본 뒤 채점해요")
            .font(.system(size: 12.5))
            .foregroundStyle(Palette.subtle)
    }

    private var emptyState: some View {
        VStack(spacing: Space.s3) {
            Spacer()
            Image(systemName: "rectangle.on.rectangle.angled")
                .font(.system(size: 40))
                .foregroundStyle(Palette.muted)
            Text("아직 카드가 없어요")
                .font(.system(size: 15))
                .foregroundStyle(Palette.subtle)
            Spacer()
        }
    }

    // MARK: - Actions

    private func mark(_ card: Flashcard, known: Bool) {
        marks[card.id] = known
        UISelectionFeedbackGenerator().selectionChanged()
        if marks.count >= session.count {
            withAnimation(.easeInOut(duration: 0.25)) { showSummary = true }
        } else {
            withAnimation(.easeInOut(duration: 0.3)) { advanceToNextUnmarked() }
        }
    }

    /// 현재 위치 다음으로 아직 채점 안 한 카드로 이동(끝까지 가면 앞으로 순환).
    private func advanceToNextUnmarked() {
        let n = session.count
        guard n > 0 else { return }
        for step in 1...n {
            let cand = (index + step) % n
            if marks[session[cand].id] == nil {
                index = cand
                return
            }
        }
    }

    private func shuffle() {
        withAnimation(.easeInOut(duration: 0.2)) {
            session.shuffle()
            index = 0
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func restartUnknown() {
        let unknowns = session.filter { marks[$0.id] == false }
        withAnimation(.easeInOut(duration: 0.25)) {
            session = unknowns
            marks = [:]
            index = 0
            showSummary = false
        }
    }

    private func restartAll() {
        withAnimation(.easeInOut(duration: 0.25)) {
            session = cards
            marks = [:]
            index = 0
            showSummary = false
        }
    }
}

// MARK: - 한 장 (탭으로 뒤집기 + 채점)

private struct FlipCard: View {
    let card: Flashcard
    /// 이전 채점 결과(있으면 해당 버튼 강조). nil = 아직 미채점.
    let mark: Bool?
    var onMark: (Bool) -> Void

    @State private var showAnswer = false

    var body: some View {
        VStack(spacing: 14) {
            cardFace
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        showAnswer.toggle()
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                }

            markRow
                .frame(height: 48)
                .opacity(showAnswer ? 1 : 0)
                .allowsHitTesting(showAnswer)
                .animation(.easeInOut(duration: 0.2), value: showAnswer)
        }
        // 카드가 바뀌면 항상 질문 면으로 초기화
        .id(card.id)
    }

    private var cardFace: some View {
        ZStack {
            face(label: "질문", text: card.question, accent: Palette.Highlight.yellow)
                .opacity(showAnswer ? 0 : 1)

            face(label: "정답", text: card.answer, accent: Palette.Highlight.orange)
                .opacity(showAnswer ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .rotation3DEffect(.degrees(showAnswer ? 180 : 0), axis: (x: 0, y: 1, z: 0))
    }

    private var markRow: some View {
        HStack(spacing: 10) {
            markButton(known: false, selected: mark == false) { onMark(false) }
            markButton(known: true, selected: mark == true) { onMark(true) }
        }
    }

    private func markButton(known: Bool, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: known ? "checkmark" : "arrow.counterclockwise")
                    .font(.system(size: 14, weight: .semibold))
                Text(known ? "알아!" : "모르겠어")
                    .font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .foregroundStyle(known ? Palette.cream : Palette.brown)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(known ? Palette.brown : Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        known ? Palette.brown : Palette.brown.opacity(0.35),
                        lineWidth: selected ? 2.5 : 1
                    )
            )
            .shadow(color: selected ? Palette.brown.opacity(0.22) : .clear, radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func face(label: String, text: String, accent: Color) -> some View {
        VStack(spacing: Space.s4) {
            HStack(spacing: 6) {
                Circle().fill(accent).frame(width: 8, height: 8)
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(Palette.subtle)
            }

            Spacer()

            Text(text)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, Space.s4)
                .textSelection(.enabled)

            Spacer()

            Text(label == "질문" ? "탭하면 정답" : "탭하면 질문")
                .font(.system(size: 11.5))
                .foregroundStyle(Palette.muted)
        }
        .padding(Space.s5)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Palette.divider, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 10)
    }
}

// MARK: - 완료 화면

private struct SummaryView: View {
    let total: Int
    let known: Int
    let unknown: Int
    var onReviewUnknown: (() -> Void)?
    var onRestartAll: () -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: Space.s4) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundStyle(Palette.brown)

            VStack(spacing: 6) {
                Text("\(total)장 다 봤어요")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Text("알아요 \(known) · 다시 볼 카드 \(unknown)")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.subtle)
            }

            VStack(spacing: 10) {
                if let onReviewUnknown {
                    primaryButton("모르는 \(unknown)장 다시 보기", action: onReviewUnknown)
                }
                secondaryButton("처음부터 다시", action: onRestartAll)
                secondaryButton("닫기", action: onClose)
            }
            .padding(.horizontal, 32)
            .padding(.top, Space.s2)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.cream)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(Palette.brown))
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Palette.brown)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Capsule().fill(Palette.surface))
                .overlay(Capsule().strokeBorder(Palette.divider, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let note = Note(title: "샘플", source: .pdf, pageCount: 1)
    let c1 = Flashcard(question: "베타락탐계 항생제의 작용은?", answer: "세포벽 합성을 억제한다.")
    let c2 = Flashcard(question: "신독성은 어떤 지표로 추적하나?", answer: "BUN/Cr 상승")
    c1.note = note; c2.note = note
    return FlashcardStudyView(cards: [c1, c2], onClose: {})
}
