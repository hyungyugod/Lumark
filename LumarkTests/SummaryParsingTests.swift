//
//  SummaryParsingTests.swift
//  LumarkTests
//
//  AI 정리본 응답 파싱 + 블록 렌더 파서 단위 테스트. 네트워크 호출 없음.
//

import Testing
import Foundation
@testable import Lumark

@Suite("Summary — parsing")
struct SummaryParsingTests {

    private func raw(_ s: String) -> Data { Data(s.utf8) }

    /// {"summary_markdown": md} 를 안전하게 직렬화. 마크다운 값에 ##·따옴표가 있어도
    /// 깨지지 않도록 raw string 대신 JSONSerialization으로 만든다.
    private func summaryData(_ md: String) -> Data {
        try! JSONSerialization.data(withJSONObject: ["summary_markdown": md])
    }
    private func summaryString(_ md: String) -> String {
        String(data: summaryData(md), encoding: .utf8)!
    }

    // MARK: - 프록시 응답 (summary_markdown 직접)

    @Test("parse — 정상")
    func parseValid() throws {
        let md = try SummaryPrompt.parse(summaryData("## 제목\n- 항목 1\n- 항목 2"))
        #expect(md.contains("## 제목"))
        #expect(md.contains("항목 1"))
    }

    @Test("parse — 앞뒤 공백 trim")
    func parseTrims() throws {
        let md = try SummaryPrompt.parse(summaryData("  \n## 본문\n  "))
        #expect(md == "## 본문")
    }

    @Test("parse — summary_markdown 키 없으면 throw")
    func parseMissing() {
        #expect(throws: QuizError.self) {
            _ = try SummaryPrompt.parse(raw(#"{"foo":"bar"}"#))
        }
    }

    @Test("parse — 빈 문자열이면 throw")
    func parseEmpty() {
        #expect(throws: QuizError.self) {
            _ = try SummaryPrompt.parse(summaryData("   "))
        }
    }

    @Test("parse — 잘못된 JSON throw")
    func parseGarbage() {
        #expect(throws: QuizError.self) {
            _ = try SummaryPrompt.parse(raw("not json"))
        }
    }

    // MARK: - Gemini 응답 (candidates 래핑)

    private func wrapGemini(_ inner: String) -> Data {
        let outer: [String: Any] = ["candidates": [["content": ["parts": [["text": inner]]]]]]
        return try! JSONSerialization.data(withJSONObject: outer)
    }

    @Test("Gemini 응답 파싱 — candidates→summary_markdown")
    func parseGeminiWrapped() throws {
        let d = wrapGemini(summaryString("## 요약 핵심정리"))
        let md = try GeminiSummaryProvider.parseGeminiResponse(d)
        #expect(md.contains("## 요약"))
    }

    @Test("Gemini 응답 파싱 — candidates 없으면 throw")
    func parseGeminiMissing() {
        #expect(throws: QuizError.self) {
            _ = try GeminiSummaryProvider.parseGeminiResponse(raw(#"{"x":1}"#))
        }
    }

    // MARK: - 스키마 형태

    @Test("SummaryPrompt.schema — summary_markdown required")
    func schemaShape() throws {
        let schema = SummaryPrompt.schema()
        #expect(schema["type"] as? String == "object")
        let required = try #require(schema["required"] as? [String])
        #expect(required.contains("summary_markdown"))
    }

    // MARK: - 블록 파서 (AISummaryView 렌더용)

    @Test("SummaryBlock.parse — 헤더/불릿/문단 분해 + 빈 줄 무시")
    func parseBlocks() {
        let md = """
        ## 섹션 A
        - 첫 항목
        - 둘째 항목
        그냥 문단.

        ## 확인 필요
        - 불확실 항목
        """
        let blocks = SummaryBlock.parse(md)
        #expect(blocks.count == 6)   // 헤더2 + 불릿3 + 문단1 (빈 줄 제외)

        guard case let .heading(level, _, warn) = blocks[0].kind else {
            Issue.record("첫 블록이 헤더가 아님"); return
        }
        #expect(level == 2)
        #expect(warn == false)

        // "확인 필요" 헤더는 warn=true로 표시돼야 함.
        let hasWarn = blocks.contains {
            if case let .heading(_, t, w) = $0.kind { return w && t.contains("확인 필요") }
            return false
        }
        #expect(hasWarn)
    }

    @Test("SummaryBlock.parse — 번호목록 마커 보존")
    func parseOrdered() {
        let blocks = SummaryBlock.parse("1. 첫 단계\n2. 둘째 단계")
        #expect(blocks.count == 2)
        guard case let .bullet(_, _, marker) = blocks[0].kind else {
            Issue.record("번호목록이 불릿으로 파싱되지 않음"); return
        }
        #expect(marker == "1.")
    }
}
