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

    init() {
        if ProcessInfo.processInfo.arguments.contains("-uitest") ||
            ProcessInfo.processInfo.environment["LUMARK_SKIP_ONBOARDING"] == "1" {
            UserDefaults.standard.set(true, forKey: "lumark.onboarded")
            UserDefaults.standard.didChooseGuest = true
        }
    }

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
            // 스토어가 비호환(예: 향후 스키마 변경으로 마이그레이션 불가)이면
            // 크래시 루프 대신 손상 스토어를 백업으로 옮기고 한 번 더 시도한다.
            // 그래도 안 되면 인메모리로라도 떠서 앱이 켜지게 한다(데이터는 비지만 사용 가능).
            print("ModelContainer load failed, attempting recovery: \(error)")
            ModelStoreRecovery.relocateDefaultStore()
            if let recovered = try? ModelContainer(for: schema, configurations: [modelConfiguration]) {
                return recovered
            }
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [memoryConfig])
            } catch {
                fatalError("ModelContainer in-memory fallback failed: \(error)")
            }
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

/// SwiftData 스토어 복구 헬퍼 — 컨테이너 init 실패(스키마 비호환/손상) 시
/// 기본 스토어 파일을 백업 위치로 옮겨 깨끗한 스토어로 재시작할 수 있게 한다.
/// 손상된 스토어는 어차피 못 읽으므로, 크래시 루프를 피하는 게 최우선.
enum ModelStoreRecovery {
    static func relocateDefaultStore() {
        let fm = FileManager.default
        guard let dir = try? fm.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false
        ) else { return }
        // SwiftData 기본 스토어 3종 세트(SQLite + WAL + SHM).
        for name in ["default.store", "default.store-wal", "default.store-shm"] {
            let src = dir.appendingPathComponent(name)
            guard fm.fileExists(atPath: src.path) else { continue }
            let dst = dir.appendingPathComponent("corrupt-\(name)")
            try? fm.removeItem(at: dst)          // 이전 백업 1세트만 유지(누수 방지)
            try? fm.moveItem(at: src, to: dst)
        }
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
