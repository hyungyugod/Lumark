//
//  ColorRuleStore.swift
//  Lumark
//
//  ColorRule을 UserDefaults에 JSON으로 영속화. spec §3.
//  앱 전역 단일 인스턴스 (사용자 단위 1세트).
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class ColorRuleStore {
    static let key = "com.lumark.colorRules"
    static let shared = ColorRuleStore()

    private(set) var rules: [ColorRule]

    private init() {
        self.rules = Self.load() ?? ColorRule.defaults
    }

    // MARK: - 접근

    func rule(for color: ColorCategory) -> ColorRule? {
        rules.first { $0.color == color }
    }

    /// 색별 활성 상태. `defaultEnabled` 폴백.
    func isEnabled(_ color: ColorCategory) -> Bool {
        rule(for: color)?.isEnabled ?? color.defaultEnabled
    }

    /// 표시용 라벨. 사용자가 비워두면 색별 기본 라벨 폴백.
    func displayLabel(for color: ColorCategory) -> String {
        let trimmed = rule(for: color)?.label.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty { return trimmed }
        switch color {
        case .yellow: return "핵심"
        case .orange: return "주제"
        case .pink, .blue: return ""
        }
    }

    func setLabel(_ label: String, for color: ColorCategory) {
        guard let idx = rules.firstIndex(where: { $0.color == color }) else { return }
        rules[idx].label = label
        persist()
    }

    func setEnabled(_ enabled: Bool, for color: ColorCategory) {
        guard let idx = rules.firstIndex(where: { $0.color == color }) else { return }
        rules[idx].isEnabled = enabled
        persist()
    }

    func resetToDefaults() {
        rules = ColorRule.defaults
        persist()
    }

    // MARK: - 저장/로드

    private static func load() -> [ColorRule]? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode([ColorRule].self, from: data)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}
