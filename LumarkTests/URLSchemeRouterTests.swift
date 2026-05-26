//
//  URLSchemeRouterTests.swift
//  LumarkTests
//

import Testing
import Foundation
@testable import Lumark

@Suite("LumarkDeeplink — parse/build round trip")
struct URLSchemeRouterTests {

    @Test("import 정상 파싱")
    func parseImport() {
        let id = UUID()
        let url = URL(string: "lumark://import?id=\(id.uuidString)")!
        let result = LumarkDeeplink.parse(url)
        #expect(result == .importInbox(id: id))
    }

    @Test("scheme 다르면 nil")
    func wrongScheme() {
        let url = URL(string: "https://import?id=\(UUID().uuidString)")!
        #expect(LumarkDeeplink.parse(url) == nil)
    }

    @Test("host 다르면 nil")
    func unknownHost() {
        let url = URL(string: "lumark://unknown?id=\(UUID().uuidString)")!
        #expect(LumarkDeeplink.parse(url) == nil)
    }

    @Test("id 누락 시 nil")
    func missingID() {
        let url = URL(string: "lumark://import")!
        #expect(LumarkDeeplink.parse(url) == nil)
    }

    @Test("id가 UUID가 아니면 nil")
    func badID() {
        let url = URL(string: "lumark://import?id=not-a-uuid")!
        #expect(LumarkDeeplink.parse(url) == nil)
    }

    @Test("build → parse 라운드트립")
    func roundTrip() {
        let id = UUID()
        let url = LumarkDeeplink.importInbox(id: id).toURL()!
        #expect(LumarkDeeplink.parse(url) == .importInbox(id: id))
    }

    @Test("scheme 대소문자 무시")
    func caseInsensitive() {
        let id = UUID()
        let url = URL(string: "LUMARK://Import?id=\(id.uuidString)")!
        #expect(LumarkDeeplink.parse(url) == .importInbox(id: id))
    }
}
