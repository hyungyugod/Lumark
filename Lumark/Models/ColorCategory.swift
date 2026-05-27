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

    /// v0.1에서 실제로 노출/처리되는 색.
    /// 분홍·파랑은 enum/Theme/아이콘 브랜드 자산으로는 유지하되 파이프라인에선 비활성.
    /// v0.2에서 이 배열만 늘리면 UI/defaults가 자동 확장됨.
    nonisolated static let activeInV01: [ColorCategory] = [.yellow, .orange]

    /// 기본 라벨 (사용자가 SettingsView에서 변경 가능)
    nonisolated var defaultLabel: String {
        switch self {
        case .yellow: return "핵심"
        case .orange: return "주제"
        case .pink, .blue: return ""
        }
    }

    /// v0.1 기본 활성 여부
    nonisolated var defaultEnabled: Bool {
        ColorCategory.activeInV01.contains(self)
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
