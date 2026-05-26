//
//  Highlight.swift
//  Lumark
//
//  페이지 내 형광펜 영역 1개 = OCR 결과 1개. spec §3.
//

import Foundation
import SwiftData

@Model
final class Highlight {
    @Attribute(.unique) var id: UUID
    var colorCategoryRaw: String        // ColorCategory.rawValue
    var text: String
    var boundingBoxData: Data           // CGRect 또는 사용자 정의 인코딩
    var orderInPage: Int                // 위→아래 순서

    var page: Page?

    init(
        id: UUID = UUID(),
        colorCategory: ColorCategory,
        text: String,
        boundingBoxData: Data,
        orderInPage: Int
    ) {
        self.id = id
        self.colorCategoryRaw = colorCategory.rawValue
        self.text = text
        self.boundingBoxData = boundingBoxData
        self.orderInPage = orderInPage
    }

    var colorCategory: ColorCategory {
        ColorCategory(rawValue: colorCategoryRaw) ?? .yellow
    }
}
