//
//  FlashcardStudyView.swift
//  Lumark
//
//  플래시카드 학습 화면. 탭하면 질문↔정답 뒤집기, 좌우 스와이프로 넘기기.
//  v0.1은 단순 넘기기 (간격반복 SRS는 v0.2 백로그).
//

import SwiftUI

struct FlashcardStudyView: View {
    let cards: [Flashcard]
    var onClose: () -> Void

    @State private var index = 0
    @State private var order: [Int] = []

    var body: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if displayCards.isEmpty {
                    emptyState
                } else {
                    TabView(selection: $index) {
                        ForEach(Array(displayCards.enumerated()), id: \.offset) { i, card in
                            FlipCard(card: card)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .tag(i)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    hint
                        .padding(.bottom, Space.s4)
                }
            }
        }
        .onAppear { if order.isEmpty { order = Array(displayCards.indices) } }
    }

    private var displayCards: [Flashcard] {
        guard !order.isEmpty, order.count == cards.count else { return cards }
        return order.map { cards[$0] }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.brown)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            if !displayCards.isEmpty {
                Text("\(min(index + 1, displayCards.count)) / \(displayCards.count)")
                    .font(Typo.mono)
                    .foregroundStyle(Palette.ink2)
            }

            Spacer()

            Button {
                shuffle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(displayCards.count > 1 ? Palette.brown : Palette.muted)
                    .frame(width: 44, height: 44)
            }
            .disabled(displayCards.count <= 1)
        }
        .padding(.horizontal, 6)
        .frame(height: 52)
    }

    private var hint: some View {
        Text("카드를 탭해 뒤집고, 좌우로 넘겨요")
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

    private func shuffle() {
        withAnimation(.easeInOut(duration: 0.2)) {
            order = Array(cards.indices).shuffled()
            index = 0
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - 한 장 (탭으로 뒤집기)

private struct FlipCard: View {
    let card: Flashcard
    @State private var showAnswer = false

    var body: some View {
        ZStack {
            face(
                label: "질문",
                text: card.question,
                accent: Palette.Highlight.yellow
            )
            .opacity(showAnswer ? 0 : 1)

            face(
                label: "정답",
                text: card.answer,
                accent: Palette.Highlight.orange
            )
            .opacity(showAnswer ? 1 : 0)
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .rotation3DEffect(.degrees(showAnswer ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                showAnswer.toggle()
            }
            UISelectionFeedbackGenerator().selectionChanged()
        }
        // 카드가 바뀌면 항상 질문 면으로 초기화
        .id(card.id)
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

            Text(showAnswerHint(label))
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

    private func showAnswerHint(_ label: String) -> String {
        label == "질문" ? "탭하면 정답" : "탭하면 질문"
    }
}

#Preview {
    let note = Note(title: "샘플", source: .pdf, pageCount: 1)
    let c1 = Flashcard(question: "베타락탐계 항생제의 작용은?", answer: "세포벽 합성을 억제한다.")
    let c2 = Flashcard(question: "신독성은 어떤 지표로 추적하나?", answer: "BUN/Cr 상승")
    c1.note = note; c2.note = note
    return FlashcardStudyView(cards: [c1, c2], onClose: {})
}
