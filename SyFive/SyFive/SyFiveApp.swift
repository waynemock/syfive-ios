//
//  SyFiveApp.swift
//  SyFive
//
//  Created by Wayne Mock on 2/22/26.
//

import SwiftUI
import SwiftData
import SyLibCloud
import SyLibCore
import SyLibUI
import SyLibScoringData

@main
struct SyFiveApp: App {
    init() {
        AppLogger.appName = "SyFive"
    }

    @State private var gameNight = GameNightController()
    @State private var cloudStatus = CloudAccountStatus(containerIdentifier: SyFiveApp.cloudKitContainerID)

    static let cloudKitContainerID = "iCloud.com.syzygysoftwerksllc.SyFive"

    var sharedModelContainer: ModelContainer = {
        let schema = Schema(SyFiveApp.models)
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private(SyFiveApp.cloudKitContainerID)
        )

        #if DEBUG
        // One-shot, before a Development → Production schema deploy (D-026): flip the flag,
        // run once on a device signed into iCloud, check CloudKit Console, flip it back.
        if AppConfig.DebugCloudKit.runSchemaExercise {
            CloudKitSchema.initializeDevelopment(models: SyFiveApp.models, configuration: modelConfiguration,
                                                 containerIdentifier: SyFiveApp.cloudKitContainerID)
        }
        #endif

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    /// Every model in SyFive's store, in the order the schema has always been built.
    static let models: [any PersistentModel.Type] = ScoringSchema.current + [AppSettingsModel.self]

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(gameNight)
                .environment(cloudStatus)
                .appTextSizeCeilings()  // game screen at xxxLarge, everything else at AX2 (D-175)
                .task {
                    // Previews never ask CloudKit (32 §3).
                    if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
                        await cloudStatus.refresh()
                    }
                    await gameNight.listenForSessions()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
