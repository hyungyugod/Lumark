//
//  Page.swift
//  Lumark
//
//  Note의 페이지. imageData는 SwiftData SQLite 본체를 부풀리지 않도록 외부 저장.
//  spec §3.
//

import Foundation
import SwiftData

@Model
final class Page {
    @Attribute(.unique) var id: UUID
    var pageNumber: Int

    @Attribute(.externalStorage)
    var imageData: Data

    var note: Note?

    @Relationship(deleteRule: .cascade, inverse: \Highlight.page)
    var highlights: [Highlight] = []

    init(
        id: UUID = UUID(),
        pageNumber: Int,
        imageData: Data
    ) {
        self.id = id
        self.pageNumber = pageNumber
        self.imageData = imageData
    }
}
