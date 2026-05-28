//
//  ProxyOCRProviderTests.swift
//  LumarkTests
//
//  프록시 응답 파싱 + 에러 메시지 추출 단위 테스트. 네트워크 호출 없음.
//

import Testing
import Foundation
@testable import Lumark

@Suite("ProxyOCRProvider — response contract")
struct ProxyOCRProviderTests {

    private func data(_ s: String) -> Data { Data(s.utf8) }

    @Test("parseSpansResponse — 정상")
    func parseValid() throws {
        let d = data(#"{"spans": [{"text": "제목", "color": "orange"}, {"text": "본문", "color": "yellow"}]}"#)
        let spans = try ProxyOCRProvider.parseSpansResponse(data: d)
        #expect(spans.count == 2)
        #expect(spans[0].color == .orange)
        #expect(spans[1].text == "본문")
        #expect(spans[0].boundingBox == nil)
    }

    @Test("parseSpansResponse — 빈 spans")
    func parseEmpty() throws {
        let spans = try ProxyOCRProvider.parseSpansResponse(data: data(#"{"spans": []}"#))
        #expect(spans.isEmpty)
    }

    @Test("parseSpansResponse — 빈 텍스트/비활성색 제외")
    func parseFilters() throws {
        let d = data(#"{"spans": [{"text":"  ","color":"yellow"},{"text":"분홍","color":"pink"},{"text":"ok","color":"yellow"}]}"#)
        let spans = try ProxyOCRProvider.parseSpansResponse(data: d)
        #expect(spans.count == 1)
        #expect(spans[0].text == "ok")
    }

    @Test("parseSpansResponse — spans 없으면 throw")
    func parseMissing() {
        #expect(throws: OCRProviderError.self) {
            _ = try ProxyOCRProvider.parseSpansResponse(data: data(#"{"foo": 1}"#))
        }
    }

    @Test("errorMessage — 프록시 에러 JSON에서 메시지 추출")
    func errorMsg() {
        let msg = ProxyOCRProvider.errorMessage(from: data(#"{"error": "기기 일일 한도 초과", "scope": "device"}"#))
        #expect(msg == "기기 일일 한도 초과")
    }

    @Test("errorMessage — error 키 없으면 nil")
    func errorMsgNil() {
        #expect(ProxyOCRProvider.errorMessage(from: data(#"{"spans": []}"#)) == nil)
    }
}
