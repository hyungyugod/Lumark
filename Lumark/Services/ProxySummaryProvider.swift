//
//  ProxySummaryProvider.swift
//  Lumark
//
//  Lumark Cloud 프록시 경유 AI 정리본 생성. 키 없이, 서버 한도 안에서.
//  요청: POST {endpoint} { "text": "..." }
//  응답: { "summary_markdown": "..." }
//
//  ProxyQuizProvider와 같은 재시도·크레딧 동기화·HTTP 매핑을 쓴다.
//  (재시도 판정은 ProxyQuizProvider.isRetryable, 에러 타입은 QuizError를 재사용.)
//

import Foundation

struct ProxySummaryProvider: SummaryProvider {
    let endpoint: String
    let appToken: String?

    nonisolated init(endpoint: String, appToken: String? = nil) {
        self.endpoint = endpoint
        self.appToken = appToken
    }

    func generate(from text: String) async throws -> String {
        // 콜드 스타트/끊긴 연결 등 일시 오류는 백오프를 두고 최대 2회 자동 재시도.
        let backoffsNs: [UInt64] = [700_000_000, 1_800_000_000]   // 0.7s, 1.8s
        var attempt = 0
        while true {
            do {
                return try await performGenerate(from: text)
            } catch let e as QuizError where ProxyQuizProvider.isRetryable(e) && attempt < backoffsNs.count {
                try? await Task.sleep(nanoseconds: backoffsNs[attempt])
                attempt += 1
            }
        }
    }

    private func performGenerate(from text: String) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw QuizError.emptyInput }
        guard let url = URL(string: endpoint), endpoint.hasPrefix("https://") else {
            throw QuizError.invalidResponse("Lumark Cloud 엔드포인트 미설정")
        }
        // 로그인 JWT(필요 시 자동 갱신).
        guard let token = await AuthManager.shared.freshAccessToken() else {
            throw QuizError.notSignedIn
        }

        let payload: [String: Any] = ["text": trimmed]
        let bodyData = try JSONSerialization.data(withJSONObject: payload)

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let appToken, !appToken.isEmpty {
            req.setValue(appToken, forHTTPHeaderField: "X-App-Token")
        }
        req.httpBody = bodyData
        req.timeoutInterval = 90   // 정리본은 출력이 길어 퀴즈(60s)보다 여유를 둔다.

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
            throw QuizError.serviceBusy(serverMsg ?? "오늘 무료 사용량이 다 찼어요. 내일 다시 충전돼요.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw QuizError.api(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }

        // 응답이 알려준 최신 잔액 + 전체 사용량 반영.
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let credits = obj["credits"] as? Int {
                await AuthManager.shared.setCreditsFromServer(credits)
            }
            if let rem = obj["global_remaining"] as? Int, let cap = obj["global_cap"] as? Int {
                await AuthManager.shared.setGlobalUsage(remaining: rem, cap: cap)
            }
        }
        // 프록시는 {summary_markdown:"..."}를 그대로 반환.
        return try SummaryPrompt.parse(data)
    }
}
