//
//  SyFiveApp.swift
//  SyFive
//
//  Created by Wayne Mock on 2/22/26.
//

import SwiftUI
import SwiftData

@main
struct SyFiveApp: App {
    @State private var gameNight = GameNightController()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            PlayerModel.self,
            TeamModel.self,
            GameModel.self,
            MatchModel.self,
            ParticipantModel.self,
            AppSettingsModel.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.com.syzygysoftwerksllc.SyFive")
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(gameNight)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .task {
                    await gameNight.listenForSessions()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
