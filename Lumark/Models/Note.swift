//
//  Note.swift
//  Lumark
//
//  변환 1회 = 1개의 Note. spec §3.
//

import Foundation
import SwiftData

@Model
final class Note {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var sourceType: String       // "pdf" / "image"
    var pageCount: Int
    var originalFilename: String?
    var isFavorite: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \Page.note)
    var pages: [Page] = []

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = .now,
        sourceType: String,
        pageCount: Int,
        originalFilename: String? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.sourceType = sourceType
        self.pageCount = pageCount
        self.originalFilename = originalFilename
        self.isFavorite = isFavorite
    }
}
