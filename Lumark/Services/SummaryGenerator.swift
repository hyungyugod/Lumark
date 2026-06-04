//
//  SummaryGenerator.swift
//  Lumark
//
//  정리된 노트 텍스트 → AI가 재구조화한 "정리본"(마크다운 한 편).
//  퀴즈와 같은 경로 정책: Lumark Cloud(프록시) 또는 본인 Gemini 키.
//  에러 타입·엔진 지원 판정은 퀴즈 인프라(QuizError / QuizGenerator.support)를 그대로 재사용한다.
//

import Foundation

protocol SummaryProvider: Sendable {
    /// 노트 텍스트를 재구조화한 마크다운 정리본 한 편으로.
    func generate(from text: String) async throws -> String
}

// MARK: - 선택

@MainActor
enum SummaryGenerator {
    /// 현재 설정으로 정리본 생성이 가능한지 사전 확인.
    /// 엔진 기반 판정이 퀴즈와 100% 동일하므로 QuizGenerator.support()를 그대로 재사용.
    static func support() -> QuizSupport { QuizGenerator.support() }

    /// 현재 OCR 엔진 설정에 맞는 정리본 provider.
    static func selectedProvider() -> SummaryProvider {
        let prefs = OCRPreferences.shared
        switch prefs.engine {
        case .lumarkCloud:
            return ProxySummaryProvider(
                endpoint: OCRPreferences.lumarkCloudSummaryEndpoint,
                appToken: OCRPreferences.appToken
            )
        case .geminiFlash:
            if let key = SecureStore.load("lumark.ocr.geminiAPIKey") {
                return GeminiSummaryProvider(apiKey: key, model: prefs.geminiModel.rawValue)
            }
            return UnsupportedSummaryProvider(reason: .missingAPIKey)
        case .appleVision:
            return UnsupportedSummaryProvider(reason: .engineUnsupported)
        }
    }
}

/// 항상 같은 에러를 내는 폴백. (퀴즈와 동일 에러 타입 재사용)
struct UnsupportedSummaryProvider: SummaryProvider {
    let reason: QuizError
    func generate(from text: String) async throws -> String { throw reason }
}

// MARK: - 공용 프롬프트 / 스키마 / 파싱

enum SummaryPrompt {
    /// 서버 summaryPrompt()와 동일 원칙(논리·예시 verbatim 보존, 새 내용 금지, "확인 필요" 분리).
    /// 본인 키 경로(GeminiSummaryProvider)에서 사용. Cloud 경로는 서버가 프롬프트를 붙인다.
    static let text = """
    아래는 학생이 형광펜으로 정리한 학습 노트입니다. 이 내용을 시험 공부에 바로 쓸 수 있도록 더 명확한 구조의 마크다운 "정리본"으로 다시 써주세요.

    [가장 중요 — 원본 보존]
    - 원본의 논리 구조(인과·흐름·조건·의사결정)는 그대로 보존하세요. 메커니즘이 결론보다 핵심입니다. 축약·변형 금지.
    - 원본에 있는 예시·수치 계산 과정·비유·풀어 쓴 설명은 생략하지 말고 유지하세요.
    - 노트에 실제로 있는 내용만 사용하세요. 새로운 사실·정의·예시를 지어내지 마세요.

    [재구조화 방법]
    - 관련된 내용을 주제별로 묶고 제목(##)·소제목(###)·글머리표(-)로 위계를 잡으세요.
    - 어렵거나 압축된 표현은 의미가 바뀌지 않는 선에서 쉬운 말을 함께 적어주세요(원래 용어는 유지).
    - 흐름이 있는 내용은 순서가 드러나게 정리하세요.

    [불확실 항목]
    - 근거가 불분명하거나 원본만으로 판단하기 어려운 항목은 임의로 고치거나 지우지 말고, 맨 끝에 "## 확인 필요" 섹션으로 따로 모아 적으세요.

    [출력 형식]
    - 마크다운 본문만. 노트 제목을 최상단 #으로 다시 쓰지 말고 ## 섹션부터 시작하세요.
    - 한국어로.

    응답: {"summary_markdown": "여기에 마크다운 정리본 전체"}
    """

    /// Gemini generationConfig.responseSchema. 마크다운 통째를 받는 단일 문자열 필드.
    /// (순수 함수 — 본인 키 경로의 nonisolated 컨텍스트에서도 호출되므로 nonisolated.)
    nonisolated static func schema() -> [String: Any] {
        [
            "type": "object",
            "properties": ["summary_markdown": ["type": "string"]],
            "required": ["summary_markdown"],
        ]
    }

    /// `{"summary_markdown":"..."}` 모양의 JSON Data → 마크다운 문자열.
    nonisolated static func parse(_ data: Data) throws -> String {
        let obj: Any
        do { obj = try JSONSerialization.jsonObject(with: data) }
        catch { throw QuizError.invalidResponse("JSON 파싱 실패") }
        guard let dict = obj as? [String: Any],
              let md = (dict["summary_markdown"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !md.isEmpty else {
            throw QuizError.invalidResponse("summary_markdown 없음")
        }
        return md
    }
}
