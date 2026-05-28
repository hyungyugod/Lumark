//
//  GeminiQuizProvider.swift
//  Lumark
//
//  본인 Gemini 키로 직접 텍스트 → 퀴즈 생성.
//

import Foundation

struct GeminiQuizProvider: QuizProvider {
    let apiKey: String
    let model: String

    nonisolated init(apiKey: String, model: String = "gemini-2.5-flash-lite") {
        self.apiKey = apiKey
        self.model = model
    }

    func generate(from text: String, count: Int) async throws -> [QuizCard] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw QuizError.emptyInput }

        let body: [String: Any] = [
            "contents": [["parts": [["text": QuizPrompt.text(count: count) + "\n\n---\n\n" + trimmed]]]],
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseSchema": QuizPrompt.schema,
                "maxOutputTokens": 4096,
                "temperature": 0.2,
            ],
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
        guard let url = URL(string: endpoint) else {
            throw QuizError.invalidResponse("URL 생성 실패")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        req.httpBody = bodyData
        req.timeoutInterval = 60

        let data: Data, resp: URLResponse
        do { (data, resp) = try await URLSession.shared.data(for: req) }
        catch { throw QuizError.network(error) }

        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw QuizError.api(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        return try Self.parseGeminiResponse(data)
    }

    /// candidates[0].content.parts[0].text(JSON 문자열) → cards.
    nonisolated static func parseGeminiResponse(_ data: Data) throws -> [QuizCard] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = root["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let inner = parts.first?["text"] as? String,
              let innerData = inner.data(using: .utf8) else {
            throw QuizError.invalidResponse("candidates 경로 파싱 실패")
        }
        return try QuizPrompt.parseCards(innerData)
    }
}
