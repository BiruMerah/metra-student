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
        TabView(selection: $coordinator.selectedTab) {
            NavigationStack(path: $coordinator.channelPath) {
                coordinator.buildChannel()
                    .navigationDestination(for: AppRoutes.self) { route in
                        coordinator.buildDestination(for: route)
                    }
            }
            .tabItem {
                Label(AppTab.channel.title, systemImage: AppTab.channel.iconName)
            }
            .tag(AppTab.channel)
            
            NavigationStack(path: $coordinator.documentPath) {
                coordinator.buildDocument()
                    .navigationDestination(for: AppRoutes.self) { route in
                        coordinator.buildDestination(for: route)
                    }
            }
            .tabItem {
                Label(AppTab.document.title, systemImage: AppTab.document.iconName)
            }
            .tag(AppTab.document)
        }
    }
}

#Preview {
    let coordinator = AppCoordinator.makePreview()
    return ContentView(coordinator: coordinator)
}
