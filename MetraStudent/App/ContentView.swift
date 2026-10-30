//
//  ContentView.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 28/10/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Bindable var coordinator: AppCoordinator
    
    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }
    
    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            NavigationStack(path: $coordinator.classroomPath) {
                coordinator.buildClassroom()
                    .navigationDestination(for: AppRoutes.self) { route in
                        coordinator.buildDestination(for: route)
                    }
            }
            .tabItem {
                Label(AppTab.classroom.title, systemImage: AppTab.classroom.iconName)
            }
            .tag(AppTab.classroom)
            
            NavigationStack(path: $coordinator.libraryPath) {
                coordinator.buildLibrary()
                    .navigationDestination(for: AppRoutes.self) { route in
                        coordinator.buildDestination(for: route)
                    }
            }
            .tabItem {
                Label(AppTab.library.title, systemImage: AppTab.library.iconName)
            }
            .tag(AppTab.library)
        }
    }
}

#Preview {
    let coordinator = AppCoordinator(
        networkManager: NetworkManager(),
        mathMaterialRepository: MathMaterialRepository(
            modelContext: ModelContext(
                try! ModelContainer(for: DatabaseSchema.schema)
            )
        )
    )
    return ContentView(coordinator: coordinator)
}
