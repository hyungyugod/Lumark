//
//  ProxyQuizProvider.swift
//  Lumark
//
//  Lumark Cloud 프록시 경유 퀴즈 생성. 키 없이, 서버 한도 안에서.
//  요청: POST {endpoint} { "text": "...", "count": N }  헤더 X-Device-ID
//  응답: { "cards": [{ "question", "answer" }] }
//

import Foundation

struct ProxyQuizProvider: QuizProvider {
    let endpoint: String
    let deviceID: String

    nonisolated init(endpoint: String, deviceID: String) {
        self.endpoint = endpoint
        self.deviceID = deviceID
    }

    func generate(from text: String, count: Int) async throws -> [QuizCard] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw QuizError.emptyInput }
        guard let url = URL(string: endpoint), endpoint.hasPrefix("https://") else {
            throw QuizError.invalidResponse("Lumark Cloud 엔드포인트 미설정")
        }

        let payload: [String: Any] = ["text": trimmed, "count": count]
        let bodyData = try JSONSerialization.data(withJSONObject: payload)

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(deviceID, forHTTPHeaderField: "X-Device-ID")
        req.httpBody = bodyData
        req.timeoutInterval = 60

        let data: Data, resp: URLResponse
        do { (data, resp) = try await URLSession.shared.data(for: req) }
        catch { throw QuizError.network(error) }

        guard let http = resp as? HTTPURLResponse else {
            throw QuizError.invalidResponse("HTTPURLResponse 아님")
        }
        if http.statusCode == 429 {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw QuizError.api(status: 429, body: msg ?? "오늘 사용량 한도에 도달했어요.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw QuizError.api(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        // 프록시는 {cards:[...]}를 그대로 반환
        return try QuizPrompt.parseCards(data)
    }
}
