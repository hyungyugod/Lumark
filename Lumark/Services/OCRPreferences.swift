//
//  OCRPreferences.swift
//  Lumark
//
//  사용자가 선택한 OCR 엔진 + API 키 보관. UserDefaults (선택) + Keychain (키).
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class OCRPreferences {
    static let shared = OCRPreferences()

    private static let engineKey       = "lumark.ocr.engine"
    private static let geminiKeyName   = "lumark.ocr.geminiAPIKey"
    private static let geminiModelKey  = "lumark.ocr.geminiModel"

    /// 현재 선택된 OCR 엔진.
    var engine: OCREngine {
        didSet {
            UserDefaults.standard.set(engine.rawValue, forKey: Self.engineKey)
            // hasGeminiKey 캐시 갱신 — 엔진 바뀌어도 키 자체는 그대로
        }
    }

    /// Gemini 모델 선택. quota 정책 변동 대응.
    var geminiModel: GeminiModel {
        didSet {
            UserDefaults.standard.set(geminiModel.rawValue, forKey: Self.geminiModelKey)
        }
    }

    /// Gemini API 키 보유 여부 (Settings UI에서 placeholder/입력 상태 표시).
    /// 키 자체는 노출하지 않음 — load는 selectedProvider 안에서만.
    private(set) var hasGeminiKey: Bool

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.engineKey)
        self.engine = raw.flatMap { OCREngine(rawValue: $0) } ?? .appleVision
        let modelRaw = UserDefaults.standard.string(forKey: Self.geminiModelKey)
        // 기본값은 Flash Lite (가장 저렴, 무료 배포 비용 최소화). 과거 기본값
        // 2.0-flash가 저장돼 있으면 신규 계정에선 404이므로 Flash Lite로 자동 승격.
        let resolved = modelRaw.flatMap { GeminiModel(rawValue: $0) } ?? .flashLite25
        self.geminiModel = (resolved == .flash20) ? .flashLite25 : resolved
        self.hasGeminiKey = SecureStore.load(Self.geminiKeyName) != nil
    }

    /// Settings UI에서 호출. 빈 문자열이면 키 삭제로 취급.
    func setGeminiAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            SecureStore.delete(Self.geminiKeyName)
            hasGeminiKey = false
        } else {
            SecureStore.save(trimmed, key: Self.geminiKeyName)
            hasGeminiKey = true
        }
    }

    /// 현재 설정에 맞는 OCRProvider 인스턴스 생성.
    /// Gemini가 선택됐는데 키가 없으면 missingAPIKey 에러를 throw하는 provider 반환.
    func selectedProvider() -> OCRProvider {
        switch engine {
        case .appleVision:
            return VisionOCRProvider()
        case .geminiFlash:
            guard let key = SecureStore.load(Self.geminiKeyName) else {
                return MissingKeyProvider(engine: .geminiFlash)
            }
            return GeminiOCRProvider(apiKey: key, model: geminiModel.rawValue)
        }
    }
}

// MARK: - Vision 래퍼

/// 기존 OCRService를 OCRProvider 인터페이스에 맞춤.
/// region별 OCR → region 색 + bbox를 그대로 span에 보존 (디버그 오버레이 유지).
struct VisionOCRProvider: OCRProvider {
    func recognizePage(image: UIImage, regions: [DetectedRegion]) async throws -> [OCRSpan] {
        let texts = await OCRService.recognize(in: image, regions: regions)
        return zip(regions, texts).map { region, text in
            OCRSpan(text: text, color: region.color, boundingBox: region.boundingBox)
        }
    }
}

/// API 키가 비어있을 때 일관된 에러를 내는 폴백 provider.
struct MissingKeyProvider: OCRProvider {
    let engine: OCREngine
    func recognizePage(image: UIImage, regions: [DetectedRegion]) async throws -> [OCRSpan] {
        throw OCRProviderError.missingAPIKey(engine: engine)
    }
}
