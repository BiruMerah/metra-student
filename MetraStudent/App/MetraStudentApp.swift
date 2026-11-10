//
//  MetraStudentApp.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 28/10/26.
//

import SwiftUI
import SwiftData

@main
struct MetraStudentApp: App {
    @State private var coordinator: AppCoordinator
    private let modelContainer: ModelContainer
    
    init() {
        // MARK: - Data Layer setup
        let container: ModelContainer
        let storageIsPersistent: Bool
        do {
            let config = ModelConfiguration(
                schema: DatabaseSchema.schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none // Prevent conflict with cloudKit entitlement
            )
            container = try ModelContainer(for: DatabaseSchema.schema, configurations: config)
            storageIsPersistent = true
        } catch {
            print("SwiftData store error: \(error). Falling back to in-memory store.")
            do {
                let fallbackConfig = ModelConfiguration(
                    schema: DatabaseSchema.schema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                )
                container = try ModelContainer(for: DatabaseSchema.schema, configurations: fallbackConfig)
                storageIsPersistent = false
            } catch {
                fatalError("Failed to initialize SwiftData ModelContainer: \(error)")
            }
        }
        self.modelContainer = container
        let mathMaterialRepository = MathMaterialRepository(modelContext: modelContainer.mainContext)
        let notificationManager = NotificationManager()
        
        // MARK: - Presentation Layer setup
        let initialCoordinator = AppCoordinator(
            mathMaterialRepository: mathMaterialRepository,
            notificationManager: notificationManager,
            storageIsPersistent: storageIsPersistent
        )
        _coordinator = State(wrappedValue: initialCoordinator)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(coordinator: coordinator)
        }
        .environment(\.locale, Locale(identifier: "id-ID"))
    }
}
