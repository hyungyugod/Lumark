//
//  Flashcard.swift
//  Lumark
//
//  노트에서 생성한 학습용 Q&A 카드. spec v0.2 백로그 "퀴즈 카드 변환"의 v0.1 구현.
//  형광펜으로 추출된 정리 내용을 LLM이 질문/정답 쌍으로 변환해 누적 저장.
//

import Foundation
import SwiftData

@Model
final class Flashcard {
    @Attribute(.unique) var id: UUID
    var question: String
    var answer: String
    var createdAt: Date
    /// 어느 노트에서 생성됐는지 (역관계). 노트 삭제 시 함께 삭제.
    var note: Note?

    init(
        id: UUID = UUID(),
        question: String,
        answer: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.question = question
        self.answer = answer
        self.createdAt = createdAt
    }
}
