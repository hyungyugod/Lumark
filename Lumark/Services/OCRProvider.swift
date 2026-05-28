//
//  OCRProvider.swift
//  Lumark
//
//  OCR 엔진 추상화. 기본은 Apple Vision (오프라인·무료), 옵션으로 Gemini 등 클라우드 LLM.
//  spec §7 S2 합격선 미달 시 외부 OCR로 교체할 수 있도록 한 인터페이스만 둠.
//

import Foundation
import UIKit

/// 사용 가능한 OCR 엔진. UserDefaults 영속화를 위해 raw String.
enum OCREngine: String, Codable, CaseIterable, Sendable, Identifiable {
    case appleVision
    case geminiFlash

    nonisolated var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .appleVision: return "Apple Vision (오프라인)"
        case .geminiFlash: return "Gemini 2.0 Flash (Google AI)"
        }
    }

    /// 요금/사용 안내 한 줄. Settings UI에서 보조 텍스트로 사용.
    nonisolated var blurb: String {
        switch self {
        case .appleVision:
            return "온디바이스. 무료·오프라인. 한국어 인쇄체 정확도 보통."
        case .geminiFlash:
            return "Google AI Studio API 키 필요. 무료 티어 일 1,500요청. 한국어 OCR 정확도 높음."
        }
    }

    nonisolated var requiresAPIKey: Bool {
        switch self {
        case .appleVision: return false
        case .geminiFlash: return true
        }
    }

    nonisolated var requiresNetwork: Bool {
        switch self {
        case .appleVision: return false
        case .geminiFlash: return true
        }
    }
}

/// Gemini 모델 선택지. 무료 티어 정책 변동(2025-12 축소)에 대응해 사용자가
/// 바꿀 수 있게 노출. raw String이 그대로 API model 경로.
enum GeminiModel: String, Codable, CaseIterable, Sendable, Identifiable {
    // 신규 계정에서 사용 가능한 2.5 계열을 먼저. 2.0/1.5는 신규 사용자에겐 404.
    case flash25     = "gemini-2.5-flash"
    case flashLite25 = "gemini-2.5-flash-lite"
    case flash20     = "gemini-2.0-flash"
    case flash15     = "gemini-1.5-flash"

    nonisolated var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .flash25:     return "Gemini 2.5 Flash"
        case .flashLite25: return "Gemini 2.5 Flash Lite"
        case .flash20:     return "Gemini 2.0 Flash (기존 계정 전용)"
        case .flash15:     return "Gemini 1.5 Flash (기존 계정 전용)"
        }
    }

    nonisolated var blurb: String {
        switch self {
        case .flash25:     return "정확도 높음. 신규 계정 권장 기본값."
        case .flashLite25: return "가장 저렴 + 분당 한도 높음. quota 빠듯하면 추천."
        case .flash20:     return "⚠️ 2025년 이후 신규 계정에선 404. 기존 사용자만."
        case .flash15:     return "⚠️ 구형. 신규 계정에선 막혔을 수 있음."
        }
    }
}

/// OCR 실패 케이스. ProcessingViewModel이 받아 LumarkError로 래핑.
enum OCRProviderError: Error, LocalizedError {
    case missingAPIKey(engine: OCREngine)
    case networkFailure(underlying: Error)
    case invalidResponse(detail: String)
    case apiError(status: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let e):
            return "\(e.displayName) API 키가 설정되지 않았어요. 설정에서 입력해주세요."
        case .networkFailure(let err):
            return "OCR 네트워크 오류: \(err.localizedDescription)"
        case .invalidResponse(let detail):
            return "OCR 응답을 해석할 수 없어요: \(detail)"
        case .apiError(let code, let body):
            return "OCR API 오류 (\(code)): \(body.prefix(140))"
        }
    }
}

/// OCR 결과 한 조각 = 형광펜으로 강조된 텍스트 + 색.
/// boundingBox는 Vision 경로처럼 위치를 아는 경우만 채워짐 (디버그 오버레이용).
/// Gemini 전체페이지 경로는 위치를 모르므로 nil.
struct OCRSpan: Sendable, Equatable {
    let text: String
    let color: ColorCategory
    let boundingBox: CGRect?

    nonisolated init(text: String, color: ColorCategory, boundingBox: CGRect? = nil) {
        self.text = text
        self.color = color
        self.boundingBox = boundingBox
    }
}

/// 한 페이지 이미지에서 형광펜 강조 텍스트를 색과 함께, 읽기 순서로 추출.
/// - parameters:
///   - image: 페이지 전체 UIImage
///   - regions: HSV가 찾은 영역들. Vision은 이걸 잘라 OCR하고, Gemini는
///              참고만 하거나 무시(전체 페이지를 직접 읽음).
/// 전체 실패면 throw. 부분 실패는 짧은 배열/빈 텍스트로 표현.
protocol OCRProvider: Sendable {
    func recognizePage(image: UIImage, regions: [DetectedRegion]) async throws -> [OCRSpan]
}
