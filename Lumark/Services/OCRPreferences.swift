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

    /// Lumark Cloud 프록시(Cloudflare Worker) 엔드포인트.
    /// 배포 후 `server/ocr-proxy/README.md` 5번 단계대로 여기에 URL을 채운다.
    /// 미설정(placeholder) 상태면 lumarkCloud 선택 시 안내 에러.
    static let lumarkCloudEndpoint = "https://lumark-ocr-proxy.hyungyugod.workers.dev/ocr"
    static var isCloudConfigured: Bool { !lumarkCloudEndpoint.contains("CHANGE-ME") }

    private static let engineKey       = "lumark.ocr.engine"
    private static let geminiKeyName   = "lumark.ocr.geminiAPIKey"
    private static let geminiModelKey  = "lumark.ocr.geminiModel"
    private static let deviceIDKey     = "lumark.ocr.deviceID"

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

    /// 익명 기기 식별자 — 프록시 기기당 한도 카운팅용. 개인정보 아님(랜덤 UUID).
    let deviceID: String

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.engineKey)
        // 기본값 = Lumark Cloud (키 입력 없이 바로 사용). 배포 대상.
        self.engine = raw.flatMap { OCREngine(rawValue: $0) } ?? .lumarkCloud
        let modelRaw = UserDefaults.standard.string(forKey: Self.geminiModelKey)
        // 기본값은 Flash Lite (가장 저렴, 무료 배포 비용 최소화). 과거 기본값
        // 2.0-flash가 저장돼 있으면 신규 계정에선 404이므로 Flash Lite로 자동 승격.
        let resolved = modelRaw.flatMap { GeminiModel(rawValue: $0) } ?? .flashLite25
        self.geminiModel = (resolved == .flash20) ? .flashLite25 : resolved
        self.hasGeminiKey = SecureStore.load(Self.geminiKeyName) != nil

        // 기기 UUID 생성/복원
        if let existing = UserDefaults.standard.string(forKey: Self.deviceIDKey) {
            self.deviceID = existing
        } else {
            let new = UUID().uuidString
            UserDefaults.standard.set(new, forKey: Self.deviceIDKey)
            self.deviceID = new
        }
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
        case .lumarkCloud:
            return ProxyOCRProvider(endpoint: Self.lumarkCloudEndpoint, deviceID: deviceID)
        case .geminiFlash:
            guard let key = SecureStore.load(Self.geminiKeyName) else {
                return MissingKeyProvider(engine: .geminiFlash)
            }
            return GeminiOCRProvider(apiKey: key, model: geminiModel.rawValue)
        case .appleVision:
            return VisionOCRProvider()
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
