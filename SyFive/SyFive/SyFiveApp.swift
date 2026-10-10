//
//  SyFiveApp.swift
//  SyFive
//
//  Created by Wayne Mock on 2/22/26.
//

import SwiftUI
import SwiftData
import CoreData
import SyLibCore
import SyLibScoringData

@main
struct SyFiveApp: App {
    init() {
        AppLogger.appName = "SyFive"
    }

    @State private var gameNight = GameNightController()

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
            SyFiveApp.initializeCloudKitSchema(config: modelConfiguration)
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

    #if DEBUG
    private static let cloudKitLogger = AppLogger(category: "CloudKit")

    /// Pushes every record type and field in the schema to the CloudKit Development
    /// environment, including types and optional fields the app hasn't written yet, so a
    /// Production deploy is complete. SwiftData has no direct API, so this follows Apple's
    /// pattern (as Syderal's RecordsStore does): open the same store through a throwaway
    /// NSPersistentCloudKitContainer, initialize, then unload it before ModelContainer opens
    /// the store; otherwise both stacks would try to sync. Slow and network-bound; failures
    /// (offline, no iCloud account, simulator) are logged, never fatal.
    private static func initializeCloudKitSchema(config: ModelConfiguration) {
        do {
            // The pool makes sure the Core Data container is deallocated before SwiftData
            // sets up its own stack on the same store.
            try autoreleasepool {
                let description = NSPersistentStoreDescription(url: config.url)
                description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                    containerIdentifier: cloudKitContainerID)
                // Synchronous load, so the store is ready before initializing the schema.
                description.shouldAddStoreAsynchronously = false
                guard let model = NSManagedObjectModel.makeManagedObjectModel(for: models) else {
                    cloudKitLogger.error(SyFiveApp.self, "initializeCloudKitSchema: could not build managed object model")
                    throw CocoaError(.featureUnsupported)
                }
                let container = NSPersistentCloudKitContainer(name: "SyFive", managedObjectModel: model)
                container.persistentStoreDescriptions = [description]
                var loadError: Error?
                container.loadPersistentStores { _, error in loadError = error }
                if let loadError { throw loadError }
                try container.initializeCloudKitSchema()
                if let store = container.persistentStoreCoordinator.persistentStores.first {
                    try container.persistentStoreCoordinator.remove(store)
                }
            }
            cloudKitLogger.info(SyFiveApp.self, "initializeCloudKitSchema: Development schema initialized — check CloudKit Console > Development")
        } catch {
            cloudKitLogger.error(SyFiveApp.self, "initializeCloudKitSchema failed: \(error)")
        }
    }
    #endif

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
