//
//  ContentView.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 28/10/26.
//

import SwiftUI

struct ContentView: View {
    @Bindable var coordinator: AppCoordinator
    
    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }
    
    var body: some View {
        NavigationStack(path: $coordinator.channelPath) {
            coordinator.buildHome()
                .navigationDestination(for: AppRoutes.self) { route in
                    coordinator.buildDestination(for: route)
                }
        }
    }
}

// MARK: - Preview
#Preview {
    let coordinator = AppCoordinator.makePreview()
    return ContentView(coordinator: coordinator)
}
