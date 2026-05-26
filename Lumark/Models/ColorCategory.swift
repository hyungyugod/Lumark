//
//  ColorCategory.swift
//  Lumark
//
//  형광펜 색상 분류. spec §3.
//

import SwiftUI

enum ColorCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case yellow, orange, pink, blue

    nonisolated var id: String { rawValue }

    /// 기본 라벨 (사용자가 SettingsView에서 변경 가능)
    nonisolated var defaultLabel: String {
        switch self {
        case .yellow: return "핵심"
        case .orange: return "주제"
        case .pink:   return ""
        case .blue:   return ""
        }
    }

    /// v0.1 기본 활성 여부
    nonisolated var defaultEnabled: Bool {
        switch self {
        case .yellow, .orange: return true
        case .pink, .blue:     return false
        }
    }

    /// 디자인 토큰의 형광펜 색상
    var swatch: Color {
        switch self {
        case .yellow: return Palette.Highlight.yellow
        case .orange: return Palette.Highlight.orange
        case .pink:   return Palette.Highlight.pink
        case .blue:   return Palette.Highlight.blue
        }
    }
}
