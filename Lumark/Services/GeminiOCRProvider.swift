//
//  GeminiOCRProvider.swift
//  Lumark
//
//  Google Gemini 기반 OCR — 페이지 전체를 한 번에 읽는 방식.
//
//  설계 (토큰 비용 최소화 — 무료 배포 + 개발자 자비 부담):
//    - region마다 crop해서 N번 호출하던 방식 폐기 (fragmentation + 호출 수 폭증)
//    - 페이지 1장 = API 1회. 다운샘플(긴 변 1536px)로 입력 토큰 절감.
//    - Gemini가 형광펜 영역을 직접 찾아 텍스트 + 색을 읽기 순서로 반환.
//    - response_schema로 구조 강제, maxOutputTokens로 출력 상한.
//    - 빈 페이지(HSV 색 0개) 스킵은 호출부(ProcessingViewModel)에서.
//
//  비용 추정 (gemini-2.5-flash-lite, 2026-05):
//    - 1536px 페이지 ≈ 입력 ~1k 토큰 + 출력 ~0.6k → 페이지당 ≈ 0.5원
//    - 20페이지 노트 ≈ 10원
//

import Foundation
import UIKit

struct GeminiOCRProvider: OCRProvider {
    let apiKey: String
    let model: String
    /// 다운샘플 목표 — 긴 변 픽셀. OCR 가독성과 토큰 비용의 균형점.
    let longSideTarget: CGFloat
    let jpegQuality: CGFloat

    nonisolated init(
        apiKey: String,
        model: String = "gemini-2.5-flash-lite",
        longSideTarget: CGFloat = 1536,
        jpegQuality: CGFloat = 0.82
    ) {
        self.apiKey = apiKey
        self.model = model
        self.longSideTarget = longSideTarget
        self.jpegQuality = jpegQuality
    }

    // MARK: - OCRProvider

    func recognizePage(image: UIImage, regions: [DetectedRegion]) async throws -> [OCRSpan] {
        // regions는 여기선 직접 안 씀 (호출부에서 빈 페이지 게이트로만 사용).
        // 페이지 전체를 Gemini가 읽는다.
        guard let jpeg = Self.downsampledJPEG(image, longSide: longSideTarget, quality: jpegQuality) else {
            throw OCRProviderError.invalidResponse(detail: "페이지 이미지 인코딩 실패")
        }

        let body = Self.buildRequestBody(imageData: jpeg)
        let bodyData: Data
        do {
            bodyData = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            throw OCRProviderError.invalidResponse(detail: "요청 인코딩 실패: \(error.localizedDescription)")
        }

        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else {
            throw OCRProviderError.invalidResponse(detail: "엔드포인트 URL 생성 실패")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        request.timeoutInterval = 60

        let data = try await performWithRetry(request: request)
        return try Self.parseSpansResponse(data: data)
    }

    // MARK: - 다운샘플 + 인코딩

    /// 긴 변이 longSide 이하가 되도록 축소 후 JPEG. 원본이 이미 작으면 그대로.
    nonisolated static func downsampledJPEG(_ image: UIImage, longSide: CGFloat, quality: CGFloat) -> Data? {
        let w = image.size.width
        let h = image.size.height
        guard w > 0, h > 0 else { return nil }
        let maxSide = max(w, h)
        let scale = maxSide > longSide ? longSide / maxSide : 1.0
        let target = CGSize(width: w * scale, height: h * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }

    // MARK: - 요청 본문

    /// generateContent 요청 본문. 노출 static — 단위 테스트 검증.
    nonisolated static func buildRequestBody(imageData: Data) -> [String: Any] {
        let prompt = """
        이 페이지 이미지에서 형광펜으로 강조된 텍스트만 추출하세요.

        [색 분류]
        - 노랑 형광펜 → color "yellow"
        - 주황 형광펜 → color "orange"
        - 형광펜이 칠해지지 않은 일반 텍스트, 빨간펜 밑줄/취소선/필기는 모두 무시

        [읽기 순서]
        - 위에서 아래로, 왼쪽에서 오른쪽으로
        - 2단(컬럼) 편집이면 왼쪽 단을 끝까지 읽은 뒤 오른쪽 단

        [줄 정리 — 중요]
        - 하나의 형광펜 강조가 여러 줄에 걸쳐 이어지면 반드시 하나의 항목으로 합치세요
        - 줄바꿈으로 쪼개진 단어("바"+"탕" → "바탕")나 문장은 자연스럽게 이어붙여 완성된 한 문장으로 만드세요
        - 단, 서로 떨어진 별개의 강조(다른 문장·다른 위치)는 각각 별도 항목으로 유지

        [제목 처리]
        - 섹션 제목/소제목(예: "비신생물적 증식", "2) 병리적 과형성 Hyperplasia")은 여러 어절·여러 줄이어도 절대 쪼개지 말고 하나의 항목으로
        - 같은 제목이 여러 페이지 상단에 반복되면, 매번 글자 그대로 동일한 텍스트로 반환하세요 (앱이 중복을 알아서 제거함)

        [정확성]
        - 보이는 텍스트에 충실하게. 내용을 새로 지어내거나 의미를 바꾸지 말 것
        - 이어붙이기 + 띄어쓰기 정리 정도만 허용. 그 이상의 의역·교정은 금지
        - 한국어 인쇄체 위주, 영문/숫자/괄호/기호도 보이는 대로

        응답: {"spans": [{"text": "...", "color": "yellow"}, ...]}
        형광펜이 하나도 없으면 {"spans": []}.
        """

        return [
            "contents": [[
                "parts": [
                    ["inline_data": [
                        "mime_type": "image/jpeg",
                        "data": imageData.base64EncodedString(),
                    ]],
                    ["text": prompt],
                ]
            ]],
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseSchema": [
                    "type": "object",
                    "properties": [
                        "spans": [
                            "type": "array",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "text": ["type": "string"],
                                    "color": ["type": "string", "enum": ["yellow", "orange"]],
                                ],
                                "required": ["text", "color"],
                            ]
                        ]
                    ],
                    "required": ["spans"],
                ],
                // 한 페이지 형광펜 텍스트는 길어야 수백 토큰. 폭주 방지 상한.
                "maxOutputTokens": 2048,
                "temperature": 0,
            ]
        ]
    }

    // MARK: - 응답 파싱

    /// generateContent 응답 → OCRSpan 배열 (위치 정보 없음).
    nonisolated static func parseSpansResponse(data: Data) throws -> [OCRSpan] {
        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: data)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? ""
            throw OCRProviderError.invalidResponse(detail: "최상위 JSON 파싱 실패: \(raw.prefix(140))")
        }

        guard
            let root = json as? [String: Any],
            let candidates = root["candidates"] as? [[String: Any]],
            let first = candidates.first,
            let content = first["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let firstPart = parts.first,
            let innerString = firstPart["text"] as? String
        else {
            throw OCRProviderError.invalidResponse(detail: "candidates/content/parts 경로에서 text 찾기 실패")
        }

        guard let innerData = innerString.data(using: .utf8) else {
            throw OCRProviderError.invalidResponse(detail: "inner text → Data 인코딩 실패")
        }
        let innerObj: Any
        do {
            innerObj = try JSONSerialization.jsonObject(with: innerData)
        } catch {
            throw OCRProviderError.invalidResponse(detail: "inner JSON 파싱 실패: \(innerString.prefix(140))")
        }
        guard let dict = innerObj as? [String: Any],
              let rawSpans = dict["spans"] as? [[String: Any]] else {
            throw OCRProviderError.invalidResponse(detail: "inner JSON에 spans 배열 없음: \(innerString.prefix(140))")
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
            default: return nil   // 활성색 외(분홍/파랑 등)는 v0.1에서 버림
            }
            return OCRSpan(text: trimmed, color: color, boundingBox: nil)
        }
    }

    // MARK: - 재시도

    /// 429(quota/rate)·503(overloaded)는 지수 백오프로 재시도.
    private func performWithRetry(request: URLRequest, maxAttempts: Int = 3) async throws -> Data {
        var lastBody = ""
        var lastStatus = 0
        for attempt in 0..<maxAttempts {
            if Task.isCancelled { throw CancellationError() }

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
            if (200..<300).contains(http.statusCode) {
                return data
            }

            lastStatus = http.statusCode
            lastBody = String(data: data, encoding: .utf8) ?? ""

            let retryable = http.statusCode == 429 || http.statusCode == 503
            if retryable && attempt < maxAttempts - 1 {
                let delayNs = UInt64(1_000_000_000) << UInt64(attempt)  // 1s → 2s → 4s
                try? await Task.sleep(nanoseconds: delayNs)
                continue
            }
            break
        }

        if lastStatus == 429 {
            throw OCRProviderError.apiError(
                status: 429,
                body: "무료 티어 quota 초과로 보입니다. Google AI Studio에서 billing(Tier 1)을 켜거나 설정에서 다른 모델로 바꿔보세요.\n원본: " + lastBody
            )
        }
        throw OCRProviderError.apiError(status: lastStatus, body: lastBody)
    }
}
