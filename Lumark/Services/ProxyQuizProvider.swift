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
    let appToken: String?

    nonisolated init(endpoint: String, appToken: String? = nil) {
        self.endpoint = endpoint
        self.appToken = appToken
    }

    func generate(from text: String, count: Int) async throws -> [QuizCard] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw QuizError.emptyInput }
        guard let url = URL(string: endpoint), endpoint.hasPrefix("https://") else {
            throw QuizError.invalidResponse("Lumark Cloud 엔드포인트 미설정")
        }
        // 로그인 JWT(필요 시 자동 갱신).
        guard let token = await AuthManager.shared.freshAccessToken() else {
            throw QuizError.notSignedIn
        }

        let payload: [String: Any] = ["text": trimmed, "count": count]
        let bodyData = try JSONSerialization.data(withJSONObject: payload)

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let appToken, !appToken.isEmpty {
            req.setValue(appToken, forHTTPHeaderField: "X-App-Token")
        }
        req.httpBody = bodyData
        req.timeoutInterval = 60

        let data: Data, resp: URLResponse
        do { (data, resp) = try await URLSession.shared.data(for: req) }
        catch { throw QuizError.network(error) }

        guard let http = resp as? HTTPURLResponse else {
            throw QuizError.invalidResponse("HTTPURLResponse 아님")
        }
        let serverMsg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
        if http.statusCode == 401 {
            throw QuizError.notSignedIn
        }
        if http.statusCode == 402 {
            throw QuizError.creditsExhausted(serverMsg ?? "크레딧이 부족해요. 내일 충전되거나, 설정에서 내 Gemini 키로 쓸 수 있어요.")
        }
        if http.statusCode == 429 {
            throw QuizError.api(status: 429, body: serverMsg ?? "지금 사용량이 많아요. 잠시 후 다시 시도해주세요.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw QuizError.api(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }

        // 응답이 알려준 최신 잔액 반영.
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let credits = obj["credits"] as? Int {
            await AuthManager.shared.setCreditsFromServer(credits)
        }
        // 프록시는 {cards:[...]}를 그대로 반환
        return try QuizPrompt.parseCards(data)
    }
}
