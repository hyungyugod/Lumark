//
//  Note.swift
//  Lumark
//
//  변환 1회 = 1개의 Note. spec §3.
//

import Foundation
import SwiftData

/// 변환 입력 소스 종류.
/// SwiftData 컬럼명은 호환을 위해 `sourceType: String`을 그대로 두고,
/// 사용처에서는 `source: NoteSource` 게터/세터로 접근한다.
enum NoteSource: String, Codable, Sendable, CaseIterable {
    case pdf
    case image
}

@Model
final class Note {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    /// SwiftData 직렬화용 — 사용처에서는 `source` 게터를 쓰세요.
    var sourceType: String
    var pageCount: Int
    var originalFilename: String?
    var isFavorite: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \Page.note)
    var pages: [Page] = []

    /// 이 노트에서 생성한 플래시카드들. 노트 삭제 시 함께 삭제.
    @Relationship(deleteRule: .cascade, inverse: \Flashcard.note)
    var flashcards: [Flashcard] = []

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = .now,
        source: NoteSource,
        pageCount: Int,
        originalFilename: String? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.sourceType = source.rawValue
        self.pageCount = pageCount
        self.originalFilename = originalFilename
        self.isFavorite = isFavorite
    }

    /// 타입-세이프 접근자. 알 수 없는 값(데이터 손상)은 `.pdf`로 fallback.
    var source: NoteSource {
        get { NoteSource(rawValue: sourceType) ?? .pdf }
        set { sourceType = newValue.rawValue }
    }
}
