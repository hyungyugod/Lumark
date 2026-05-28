//
//  GeminiOCRProviderTests.swift
//  LumarkTests
//
//  실제 네트워크 호출은 안 함 — 요청 본문 구조 + 응답(spans) 파싱만 단위 테스트로 잠금.
//  (전체 페이지 1장 → spans 추출 방식)
//

import Testing
import Foundation
import UIKit
@testable import Lumark

@Suite("GeminiOCRProvider — whole-page request/response contract")
struct GeminiOCRProviderTests {

    // MARK: - 요청 본문

    @Test("buildRequestBody — 단일 이미지 + prompt + spans 스키마")
    func requestBodyShape() throws {
        let img = Data("fake-jpeg".utf8)
        let body = GeminiOCRProvider.buildRequestBody(imageData: img)

        let contents = try #require(body["contents"] as? [[String: Any]])
        #expect(contents.count == 1)
        let parts = try #require(contents[0]["parts"] as? [[String: Any]])
        // image 1 + prompt 1 = 2
        #expect(parts.count == 2)

        let inline = try #require(parts[0]["inline_data"] as? [String: Any])
        #expect(inline["mime_type"] as? String == "image/jpeg")
        #expect((inline["data"] as? String)?.isEmpty == false)

        let promptText = try #require(parts[1]["text"] as? String)
        #expect(promptText.contains("형광펜"))
        #expect(promptText.contains("spans"))

        let gen = try #require(body["generationConfig"] as? [String: Any])
        #expect(gen["responseMimeType"] as? String == "application/json")
        #expect(gen["maxOutputTokens"] as? Int == 2048)
        // 스키마에 spans 배열 + color enum 존재
        let schema = try #require(gen["responseSchema"] as? [String: Any])
        let props = try #require(schema["properties"] as? [String: Any])
        #expect(props["spans"] != nil)
    }

    // MARK: - 응답 파싱

    /// 실제 Gemini 응답 형태: candidates[0].content.parts[0].text = JSON 문자열
    private func wrap(_ innerJSON: String) -> Data {
        let outer: [String: Any] = [
            "candidates": [[
                "content": ["parts": [["text": innerJSON]]]
            ]]
        ]
        return try! JSONSerialization.data(withJSONObject: outer)
    }

    @Test("parseSpansResponse — 정상 (yellow/orange 분류)")
    func parseValid() throws {
        let data = wrap(#"{"spans": [{"text": "제목", "color": "orange"}, {"text": "본문", "color": "yellow"}]}"#)
        let spans = try GeminiOCRProvider.parseSpansResponse(data: data)
        #expect(spans.count == 2)
        #expect(spans[0].text == "제목")
        #expect(spans[0].color == .orange)
        #expect(spans[1].text == "본문")
        #expect(spans[1].color == .yellow)
        // 전체페이지 경로는 bbox 없음
        #expect(spans[0].boundingBox == nil)
    }

    @Test("parseSpansResponse — 빈 spans는 빈 배열")
    func parseEmpty() throws {
        let data = wrap(#"{"spans": []}"#)
        let spans = try GeminiOCRProvider.parseSpansResponse(data: data)
        #expect(spans.isEmpty)
    }

    @Test("parseSpansResponse — 빈 텍스트 항목은 제외")
    func parseSkipsEmptyText() throws {
        let data = wrap(#"{"spans": [{"text": "  ", "color": "yellow"}, {"text": "유효", "color": "yellow"}]}"#)
        let spans = try GeminiOCRProvider.parseSpansResponse(data: data)
        #expect(spans.count == 1)
        #expect(spans[0].text == "유효")
    }

    @Test("parseSpansResponse — 활성색(노랑/주황) 외 color는 버림")
    func parseDropsInactiveColors() throws {
        let data = wrap(#"{"spans": [{"text": "분홍이", "color": "pink"}, {"text": "노랑이", "color": "yellow"}]}"#)
        let spans = try GeminiOCRProvider.parseSpansResponse(data: data)
        #expect(spans.count == 1)
        #expect(spans[0].color == .yellow)
    }

    @Test("parseSpansResponse — 잘못된 최상위 JSON은 throw")
    func parseTopLevelGarbage() {
        let bad = Data("not json".utf8)
        #expect(throws: OCRProviderError.self) {
            _ = try GeminiOCRProvider.parseSpansResponse(data: bad)
        }
    }

    @Test("parseSpansResponse — candidates 없으면 throw")
    func parseMissingCandidates() {
        let bad = try! JSONSerialization.data(withJSONObject: ["foo": "bar"])
        #expect(throws: OCRProviderError.self) {
            _ = try GeminiOCRProvider.parseSpansResponse(data: bad)
        }
    }

    @Test("parseSpansResponse — inner JSON에 spans 키 없으면 throw")
    func parseInnerMissingSpans() {
        let data = wrap(#"{"other": []}"#)
        #expect(throws: OCRProviderError.self) {
            _ = try GeminiOCRProvider.parseSpansResponse(data: data)
        }
    }

    // MARK: - 다운샘플

    @Test("downsampledJPEG — 큰 이미지는 긴 변이 목표 이하로 축소")
    func downsampleShrinksLargeImage() throws {
        let big = Self.solidImage(width: 3000, height: 4000)
        let data = try #require(GeminiOCRProvider.downsampledJPEG(big, longSide: 1536, quality: 0.8))
        let decoded = try #require(UIImage(data: data))
        #expect(max(decoded.size.width, decoded.size.height) <= 1536 + 1)
    }

    @Test("downsampledJPEG — 작은 이미지는 그대로")
    func downsampleKeepsSmallImage() throws {
        let small = Self.solidImage(width: 800, height: 1000)
        let data = try #require(GeminiOCRProvider.downsampledJPEG(small, longSide: 1536, quality: 0.8))
        let decoded = try #require(UIImage(data: data))
        #expect(max(decoded.size.width, decoded.size.height) <= 1000 + 1)
    }

    private static func solidImage(width: CGFloat, height: CGFloat) -> UIImage {
        let f = UIGraphicsImageRendererFormat()
        f.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: f).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}
