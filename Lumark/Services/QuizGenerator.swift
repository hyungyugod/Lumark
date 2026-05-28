//
//  QuizGenerator.swift
//  Lumark
//
//  정리된 노트 텍스트 → 학습용 Q&A 카드 생성. LLM(Gemini) 필요.
//  OCR과 같은 경로 정책: Lumark Cloud(프록시) 또는 본인 Gemini 키.
//  Apple Vision은 LLM이 아니라 퀴즈 생성 불가.
//

import Foundation

/// 생성된 카드 한 장 (저장 전 값 타입).
struct QuizCard: Sendable, Equatable {
    let question: String
    let answer: String
}

enum QuizError: Error, LocalizedError {
    case engineUnsupported          // Apple Vision 등 LLM 아님
    case missingAPIKey
    case emptyInput
    case network(Error)
    case api(status: Int, body: String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .engineUnsupported:
            return "퀴즈 생성은 Lumark Cloud 또는 내 Gemini 키 엔진에서만 돼요. 설정에서 바꿔주세요."
        case .missingAPIKey:
            return "Gemini API 키가 설정되지 않았어요. 설정에서 입력해주세요."
        case .emptyInput:
            return "카드를 만들 내용이 없어요."
        case .network(let e):
            return "네트워크 오류: \(e.localizedDescription)"
        case .api(let code, let body):
            return "퀴즈 API 오류 (\(code)): \(body.prefix(140))"
        case .invalidResponse(let d):
            return "퀴즈 응답을 해석할 수 없어요: \(d)"
        }
    }
}

protocol QuizProvider: Sendable {
    /// 노트 텍스트에서 최대 count개 카드 생성.
    func generate(from text: String, count: Int) async throws -> [QuizCard]
}

// MARK: - 선택

@MainActor
enum QuizGenerator {
    /// 현재 OCR 엔진 설정에 맞는 퀴즈 provider.
    static func selectedProvider() -> QuizProvider {
        let prefs = OCRPreferences.shared
        switch prefs.engine {
        case .lumarkCloud:
            return ProxyQuizProvider(
                endpoint: OCRPreferences.lumarkCloudQuizEndpoint,
                deviceID: prefs.deviceID,
                appToken: OCRPreferences.appToken
            )
        case .geminiFlash:
            if let key = SecureStore.load("lumark.ocr.geminiAPIKey") {
                return GeminiQuizProvider(apiKey: key, model: prefs.geminiModel.rawValue)
            }
            return UnsupportedQuizProvider(reason: .missingAPIKey)
        case .appleVision:
            return UnsupportedQuizProvider(reason: .engineUnsupported)
        }
    }
}

/// 항상 같은 에러를 내는 폴백.
struct UnsupportedQuizProvider: QuizProvider {
    let reason: QuizError
    func generate(from text: String, count: Int) async throws -> [QuizCard] {
        throw reason
    }
}

// MARK: - 공용 프롬프트/스키마/파싱

enum QuizPrompt {
    static func text(count: Int) -> String {
        """
        아래는 학생이 형광펜으로 정리한 학습 노트입니다. 이 내용으로 시험 대비 학습용
        Q&A 플래시카드를 최대 \(count)개 만들어주세요.

        규칙:
        - 노트에 실제로 있는 내용만 사용. 새로운 사실을 지어내지 말 것.
        - question은 핵심 개념을 묻는 한 문장. answer는 간결하고 정확하게.
        - 단순 정의·분류·특징·원인-결과 위주로 좋은 시험 문제를 만들 것.
        - 내용이 적으면 \(count)개보다 적어도 됨.
        - 한국어로.

        응답: {"cards": [{"question": "...", "answer": "..."}, ...]}
        """
    }

    /// Gemini generationConfig.responseSchema.
    static var schema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "cards": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "question": ["type": "string"],
                            "answer": ["type": "string"],
                        ],
                        "required": ["question", "answer"],
                    ]
                ]
            ],
            "required": ["cards"],
        ]
    }

    /// `{"cards":[{question,answer}]}` 모양의 JSON Data → [QuizCard].
    static func parseCards(_ data: Data) throws -> [QuizCard] {
        let obj: Any
        do { obj = try JSONSerialization.jsonObject(with: data) }
        catch { throw QuizError.invalidResponse("JSON 파싱 실패") }
        guard let dict = obj as? [String: Any],
              let raw = dict["cards"] as? [[String: Any]] else {
            throw QuizError.invalidResponse("cards 배열 없음")
        }
        return raw.compactMap { item in
            guard let q = (item["question"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let a = (item["answer"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !q.isEmpty, !a.isEmpty else { return nil }
            return QuizCard(question: q, answer: a)
        }
    }
}
