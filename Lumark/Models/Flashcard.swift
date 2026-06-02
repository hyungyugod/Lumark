//
//  Flashcard.swift
//  Lumark
//
//  노트에서 생성한 학습용 카드. 주관식(Q&A) 또는 OX(참/거짓) 유형.
//  형광펜으로 추출된 정리 내용을 LLM이 카드로 변환해 누적 저장.
//

import Foundation
import SwiftData

enum FlashcardReviewState: String, Codable, Sendable {
    case unreviewed
    case known
    case unknown
}

/// 카드 유형. 주관식(질문↔정답 뒤집기) 또는 OX(참/거짓 진술 풀기).
enum FlashcardKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case qa   // 주관식: question ↔ answer
    case ox   // OX: question=진술문, oxAnswer=정답(O=true), answer=해설

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .qa: return "주관식"
        case .ox: return "OX 퀴즈"
        }
    }
}

@Model
final class Flashcard {
    @Attribute(.unique) var id: UUID
    var question: String
    var answer: String
    var createdAt: Date
    /// 마지막 학습 표시. nil/알 수 없는 값은 미학습으로 취급.
    private var reviewStateRaw: String?
    /// 카드 유형. nil/알 수 없으면 주관식(qa)으로 취급(기존 카드 호환).
    private var kindRaw: String?
    /// OX 카드의 정답(O=true, X=false). 주관식 카드는 nil.
    private var oxAnswerRaw: Bool?
    /// 어느 노트에서 생성됐는지 (역관계). 노트 삭제 시 함께 삭제.
    var note: Note?

    var reviewState: FlashcardReviewState {
        get {
            guard let reviewStateRaw,
                  let state = FlashcardReviewState(rawValue: reviewStateRaw)
            else { return .unreviewed }
            return state
        }
        set {
            reviewStateRaw = newValue.rawValue
        }
    }

    /// 카드 유형. 기존(필드 없는) 카드는 주관식으로 취급.
    var kind: FlashcardKind {
        get {
            guard let kindRaw, let k = FlashcardKind(rawValue: kindRaw) else { return .qa }
            return k
        }
        set { kindRaw = newValue.rawValue }
    }

    /// OX 카드의 정답(O=true, X=false). 주관식이면 nil.
    var oxAnswer: Bool? {
        get { oxAnswerRaw }
        set { oxAnswerRaw = newValue }
    }

    var reviewMark: Bool? {
        switch reviewState {
        case .known: return true
        case .unknown: return false
        case .unreviewed: return nil
        }
    }

    init(
        id: UUID = UUID(),
        question: String,
        answer: String,
        createdAt: Date = .now,
        reviewState: FlashcardReviewState = .unreviewed,
        kind: FlashcardKind = .qa,
        oxAnswer: Bool? = nil
    ) {
        self.id = id
        self.question = question
        self.answer = answer
        self.createdAt = createdAt
        self.reviewStateRaw = reviewState.rawValue
        self.kindRaw = kind.rawValue
        self.oxAnswerRaw = oxAnswer
    }
}
