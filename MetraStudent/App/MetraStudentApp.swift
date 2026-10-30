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
        do {
            let config = ModelConfiguration(schema: DatabaseSchema.schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: DatabaseSchema.schema, configurations: config)
        } catch {
            print("SwiftData migration error: \(error). Falling back to in-memory store.")
            let fallbackConfig = ModelConfiguration(schema: DatabaseSchema.schema, isStoredInMemoryOnly: true)
            modelContainer = try! ModelContainer(for: DatabaseSchema.schema, configurations: fallbackConfig)
        }
        let mathMaterialRepository = MathMaterialRepository(modelContext: modelContainer.mainContext)
        let networkManager = NetworkManager()
        
        // MARK: - Presentation Layer setup
        let initialCoordinator = AppCoordinator(
            networkManager: networkManager,
            mathMaterialRepository: mathMaterialRepository
        )
        _coordinator = State(wrappedValue: initialCoordinator)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(coordinator: coordinator)
                .modelContainer(modelContainer)
        }
    }
}
