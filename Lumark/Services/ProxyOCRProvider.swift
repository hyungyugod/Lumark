//
//  ProxyOCRProvider.swift
//  Lumark
//
//  Lumark Cloud — 키 없이 자체 프록시(Cloudflare Worker) 경유로 OCR.
//
//  앱은 Gemini 키를 모른다. 다운샘플한 페이지 이미지를 프록시로 보내면,
//  프록시가 서버에 보관된 키로 Gemini를 호출하고 spans를 돌려준다.
//  기기당/전체 일일 한도는 프록시가 강제 (비용 상한).
//
//  요청:  POST {endpoint}  body { "image_base64": "..." }  header X-Device-ID
//  응답:  { "spans": [{ "text", "color" }] }  / 429 한도초과 / 기타 오류
//

import Foundation
import UIKit

struct ProxyOCRProvider: OCRProvider {
    let endpoint: String
    let appToken: String?
    let longSideTarget: CGFloat
    let jpegQuality: CGFloat

    nonisolated init(
        endpoint: String,
        appToken: String? = nil,
        longSideTarget: CGFloat = 1536,
        jpegQuality: CGFloat = 0.82
    ) {
        self.endpoint = endpoint
        self.appToken = appToken
        self.longSideTarget = longSideTarget
        self.jpegQuality = jpegQuality
    }

    func recognizePage(image: UIImage, regions: [DetectedRegion]) async throws -> [OCRSpan] {
        guard let url = URL(string: endpoint), endpoint.hasPrefix("https://") else {
            throw OCRProviderError.invalidResponse(detail: "Lumark Cloud 엔드포인트가 설정되지 않았어요. (개발자: OCRPreferences.lumarkCloudEndpoint 확인)")
        }
        // 다운샘플은 Gemini 경로와 동일 로직 재사용 (대역폭 + 서버 토큰 절약).
        guard let jpeg = GeminiOCRProvider.downsampledJPEG(image, longSide: longSideTarget, quality: jpegQuality) else {
            throw OCRProviderError.invalidResponse(detail: "페이지 이미지 인코딩 실패")
        }

        // 로그인 JWT(필요 시 자동 갱신). 없으면 로그인 안내.
        guard let token = await AuthManager.shared.freshAccessToken() else {
            throw OCRProviderError.notSignedIn
        }

        let payload: [String: Any] = ["image_base64": jpeg.base64EncodedString()]
        let bodyData: Data
        do {
            bodyData = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            throw OCRProviderError.invalidResponse(detail: "요청 인코딩 실패")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let appToken, !appToken.isEmpty {
            request.setValue(appToken, forHTTPHeaderField: "X-App-Token")
        }
        request.httpBody = bodyData
        request.timeoutInterval = 60

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw OCRProviderError.networkFailure(underlying: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw OCRProviderError.invalidResponse(detail: "HTTPURLResponse 아님")
        }
        if http.statusCode == 401 {
            throw OCRProviderError.notSignedIn
        }
        if http.statusCode == 402 {
            let msg = Self.errorMessage(from: data) ?? "크레딧이 부족해요. 내일 충전되거나, 설정에서 내 Gemini 키로 쓸 수 있어요."
            throw OCRProviderError.creditsExhausted(message: msg)
        }
        if http.statusCode == 429 {
            let msg = Self.errorMessage(from: data) ?? "지금 사용량이 많아요. 잠시 후 다시 시도해주세요."
            throw OCRProviderError.apiError(status: 429, body: msg)
        }
        guard (200..<300).contains(http.statusCode) else {
            let msg = Self.errorMessage(from: data) ?? (String(data: data, encoding: .utf8) ?? "")
            throw OCRProviderError.apiError(status: http.statusCode, body: msg)
        }

        // 응답이 알려준 최신 잔액을 반영.
        if let credits = Self.creditsValue(from: data) {
            await AuthManager.shared.setCreditsFromServer(credits)
        }
        return try Self.parseSpansResponse(data: data)
    }

    // MARK: - 파싱

    /// 프록시 응답 { "spans": [{text,color}] } → [OCRSpan].
    nonisolated static func parseSpansResponse(data: Data) throws -> [OCRSpan] {
        let obj: Any
        do {
            obj = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw OCRProviderError.invalidResponse(detail: "프록시 응답 JSON 파싱 실패")
        }
        guard let dict = obj as? [String: Any],
              let rawSpans = dict["spans"] as? [[String: Any]] else {
            throw OCRProviderError.invalidResponse(detail: "프록시 응답에 spans 없음")
        }
        return rawSpans.compactMap { item -> OCRSpan? in
            guard let text = item["text"] as? String,
                  let colorStr = item["color"] as? String else { return nil }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let color: ColorCategory
            switch colorStr.lowercased() {
            case "yellow": color = .yellow
            case "orange": color = .orange
            default: return nil
            }
            return OCRSpan(text: trimmed, color: color, boundingBox: nil)
        }
    }

    nonisolated static func errorMessage(from data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let msg = obj["error"] as? String else { return nil }
        return msg
    }

    /// 응답 본문의 `credits`(남은 잔액) 정수. 없으면 nil.
    nonisolated static func creditsValue(from data: Data) -> Int? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return obj["credits"] as? Int
    }
}
