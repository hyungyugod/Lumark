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
/// "로그인 없이 둘러보기"를 한 번 누르면 기억 → 이후 콜드 런치엔 바로 진입(매번 안 막음).
/// 로그인하면 당연히 게이트 없음.
private struct RootView: View {
    @State private var auth = AuthManager.shared
    @State private var continuedAsGuest = UserDefaults.standard.didChooseGuest

    var body: some View {
        if auth.isSignedIn || continuedAsGuest {
            HomeView()
        } else {
            SignInView(onContinueAsGuest: {
                UserDefaults.standard.didChooseGuest = true
                continuedAsGuest = true
            })
        }
    }
}
