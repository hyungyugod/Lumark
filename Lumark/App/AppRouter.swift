//
//  AppRouter.swift
//  Lumark
//
//  앱 단위 라우팅 상태. 외부 진입점(deeplink)이 HomeView로 데이터를 전달하는 통로.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class AppRouter {
    /// 처리 대기 중인 deeplink. HomeView가 consume(읽고 nil로 리셋)함.
    var pendingDeeplink: LumarkDeeplink?

    /// deeplink URL을 받아 파싱 후 pending에 넣는다.
    /// 파싱 실패 시 무시.
    func handle(url: URL) {
        guard let dl = LumarkDeeplink.parse(url) else { return }
        pendingDeeplink = dl
    }
}
