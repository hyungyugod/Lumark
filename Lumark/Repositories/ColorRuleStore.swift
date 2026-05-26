//
//  ColorRuleStore.swift
//  Lumark
//
//  ColorRule을 UserDefaults에 JSON으로 영속화. spec §3.
//  앱 전역 단일 인스턴스 (사용자 단위 1세트).
//

import Foundation
import SwiftUI

/// ColorRuleStore의 4색 상태를 한 번에 캡처한 값 타입.
/// MainActor → nonisolated(Exporter) 경계에서 안전하게 전달하기 위함.
struct ColorRuleSnapshot: Equatable, Sendable {
    let enabled: [ColorCategory: Bool]
    let labels: [ColorCategory: String]

    nonisolated init(
        enabled: [ColorCategory: Bool],
        labels: [ColorCategory: String]
    ) {
        self.enabled = enabled
        self.labels = labels
    }

    nonisolated func isEnabled(_ color: ColorCategory) -> Bool {
        enabled[color] ?? color.defaultEnabled
    }

    nonisolated func label(for color: ColorCategory) -> String {
        labels[color] ?? ""
    }
}

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

    /// 표시용 라벨. 사용자가 비워두면 색별 기본 표시 라벨 폴백.
    /// 분홍·파랑은 마크다운 "추가 메모" 섹션 헤더로도 쓰이므로 기본 라벨이 필요.
    func displayLabel(for color: ColorCategory) -> String {
        let trimmed = rule(for: color)?.label.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty { return trimmed }
        switch color {
        case .yellow: return "핵심"
        case .orange: return "주제"
        case .pink:   return "보충 (분홍)"
        case .blue:   return "참고 (파랑)"
        }
    }

    /// 4색 모두의 (활성/라벨) 스냅샷. nonisolated 출력(MarkdownExporter 등)에
    /// 통째로 넘기는 용도.
    func currentSnapshot() -> ColorRuleSnapshot {
        ColorRuleSnapshot(
            enabled: Dictionary(uniqueKeysWithValues: ColorCategory.allCases.map {
                ($0, isEnabled($0))
            }),
            labels: Dictionary(uniqueKeysWithValues: ColorCategory.allCases.map {
                ($0, displayLabel(for: $0))
            })
        )
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
