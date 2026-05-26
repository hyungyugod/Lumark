//
//  ExportPreferences.swift
//  Lumark
//
//  마크다운 출력 옵션 사용자 설정. UserDefaults 영속화.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class ExportPreferences {
    static let shared = ExportPreferences()

    private static let dialectKey = "lumark.export.dialect"
    private static let pageMapKey = "lumark.export.includePageMap"

    var dialect: MarkdownDialect {
        didSet {
            UserDefaults.standard.set(dialect.rawValue, forKey: Self.dialectKey)
        }
    }

    var includePageMap: Bool {
        didSet {
            UserDefaults.standard.set(includePageMap, forKey: Self.pageMapKey)
        }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.dialectKey)
        self.dialect = raw.flatMap(MarkdownDialect.init(rawValue:)) ?? .commonMark
        self.includePageMap = UserDefaults.standard.bool(forKey: Self.pageMapKey)
    }
}
