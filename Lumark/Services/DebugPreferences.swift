//
//  DebugPreferences.swift
//  Lumark
//
//  v0.1 디버그·검증 토글. UserDefaults 영속화.
//
//  Day 2~4 합격 게이트 (spec §7) HSV 임계값 튜닝 작업에서 검출 결과를 눈으로
//  확인하기 위한 토글들을 모은다. 사용자가 실수로 켜도 무해 — 결과 화면에서
//  검출 box가 보일 뿐.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class DebugPreferences {
    static let shared = DebugPreferences()

    private static let showOverlayKey = "lumark.debug.showDetectionOverlay"

    /// ON이면 ResultView "원본" 탭에서 실제 페이지 이미지 위에 검출 bbox를
    /// 컬러 외곽선으로 그린다.
    var showDetectionOverlay: Bool {
        didSet {
            UserDefaults.standard.set(showDetectionOverlay, forKey: Self.showOverlayKey)
        }
    }

    private init() {
        self.showDetectionOverlay = UserDefaults.standard.bool(forKey: Self.showOverlayKey)
    }
}
