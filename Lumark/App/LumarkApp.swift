//
//  LumarkApp.swift
//  Lumark
//
//  Created by HG on 5/21/26.
//

import SwiftUI
import SwiftData

@main
struct LumarkApp: App {
    @State private var router = AppRouter()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Note.self,
            Page.self,
            Highlight.self,
            Flashcard.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .onOpenURL { url in
                    router.handle(url: url)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

/// 앱 진입 게이트 — 로그인 안 했고 게스트 선택도 안 했으면 로그인 화면을 먼저 보여준다.
/// "로그인 없이 둘러보기"를 누르면 그 세션 동안 게스트로 진입(다음 콜드 런치 때 다시 게이트).
private struct RootView: View {
    @State private var auth = AuthManager.shared
    @State private var continuedAsGuest = false

    var body: some View {
        if auth.isSignedIn || continuedAsGuest {
            HomeView()
        } else {
            SignInView(onContinueAsGuest: { continuedAsGuest = true })
        }
    }
}
