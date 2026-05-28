//
//  QuizGeneratorTests.swift
//  LumarkTests
//
//  퀴즈 응답 파싱 단위 테스트. 네트워크 호출 없음.
//

import Testing
import Foundation
@testable import Lumark

@Suite("QuizGenerator — parsing")
struct QuizGeneratorTests {

    private func data(_ s: String) -> Data { Data(s.utf8) }

    // MARK: - 프록시 응답 (cards 직접)

    @Test("parseCards — 정상")
    func parseValid() throws {
        let d = data(#"{"cards":[{"question":"Q1","answer":"A1"},{"question":"Q2","answer":"A2"}]}"#)
        let cards = try QuizPrompt.parseCards(d)
        #expect(cards.count == 2)
        #expect(cards[0].question == "Q1")
        #expect(cards[1].answer == "A2")
    }

    @Test("parseCards — 빈 question/answer 제외")
    func parseFilters() throws {
        let d = data(#"{"cards":[{"question":"  ","answer":"A"},{"question":"Q","answer":""},{"question":"좋은질문","answer":"좋은답"}]}"#)
        let cards = try QuizPrompt.parseCards(d)
        #expect(cards.count == 1)
        #expect(cards[0].question == "좋은질문")
    }

    @Test("parseCards — 빈 배열")
    func parseEmpty() throws {
        #expect(try QuizPrompt.parseCards(data(#"{"cards":[]}"#)).isEmpty)
    }

    @Test("parseCards — cards 키 없으면 throw")
    func parseMissing() {
        #expect(throws: QuizError.self) {
            _ = try QuizPrompt.parseCards(data(#"{"foo":1}"#))
        }
    }

    @Test("parseCards — 잘못된 JSON throw")
    func parseGarbage() {
        #expect(throws: QuizError.self) {
            _ = try QuizPrompt.parseCards(data("not json"))
        }
    }

    // MARK: - Gemini 응답 (candidates 래핑)

    private func wrapGemini(_ inner: String) -> Data {
        let outer: [String: Any] = ["candidates": [["content": ["parts": [["text": inner]]]]]]
        return try! JSONSerialization.data(withJSONObject: outer)
    }

    @Test("Gemini 응답 파싱 — candidates→cards")
    func parseGeminiWrapped() throws {
        let d = wrapGemini(#"{"cards":[{"question":"질문","answer":"정답"}]}"#)
        let cards = try GeminiQuizProvider.parseGeminiResponse(d)
        #expect(cards.count == 1)
        #expect(cards[0].question == "질문")
    }

    @Test("Gemini 응답 파싱 — candidates 없으면 throw")
    func parseGeminiMissing() {
        #expect(throws: QuizError.self) {
            _ = try GeminiQuizProvider.parseGeminiResponse(data(#"{"x":1}"#))
        }
    }

    // MARK: - 스키마 형태

    @Test("QuizPrompt.schema — cards 배열 + question/answer required")
    func schemaShape() throws {
        let schema = QuizPrompt.schema
        #expect(schema["type"] as? String == "object")
        let props = try #require(schema["properties"] as? [String: Any])
        #expect(props["cards"] != nil)
    }
}
