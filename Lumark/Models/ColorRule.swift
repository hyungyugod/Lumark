//
//  ColorRule.swift
//  Lumark
//
//  사용자 전역 색 매핑 규칙. UserDefaults에 JSON으로 저장.
//  spec §3.
//

import Foundation

/// HSV 마스킹 범위 — Day 2~4 기술 검증(S1)에서 사용.
struct HSVRange: Codable, Equatable {
    let hMin: Double
    let hMax: Double
    let sMin: Double
    let vMin: Double
}

struct ColorRule: Codable, Identifiable, Equatable {
    let id: UUID
    let color: ColorCategory
    var label: String
    var isEnabled: Bool
    let hsvRange: HSVRange

    /// v0.1은 노랑/주황만. 분홍/파랑은 enum에 남아있지만 사용자 룰셋에는 없음.
    static let defaults: [ColorRule] = ColorCategory.activeInV01.map { c in
        ColorRule(
            id: UUID(),
            color: c,
            label: c.defaultLabel,
            isEnabled: c.defaultEnabled,
            hsvRange: defaultHSV(for: c)
        )
    }

    /// 잠정값. Day 2~4 S1 검증에서 정밀도 ≥ 95% / 재현율 ≥ 90% 통과까지 튜닝.
    private static func defaultHSV(for c: ColorCategory) -> HSVRange {
        switch c {
        case .yellow: return HSVRange(hMin: 40,  hMax: 70,  sMin: 0.30, vMin: 0.55)
        case .orange: return HSVRange(hMin: 15,  hMax: 40,  sMin: 0.35, vMin: 0.55)
        case .pink:   return HSVRange(hMin: 320, hMax: 360, sMin: 0.25, vMin: 0.55)
        case .blue:   return HSVRange(hMin: 190, hMax: 250, sMin: 0.25, vMin: 0.45)
        }
    }
}
