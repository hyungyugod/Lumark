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
            HomeView()
                .environment(router)
                .onOpenURL { url in
                    router.handle(url: url)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
