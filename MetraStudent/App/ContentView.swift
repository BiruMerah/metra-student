//
//  ContentView.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 28/10/26.
//

import SwiftUI

struct ContentView: View {
    @State private var coordinator: AppCoordinator
    
    init(coordinator: AppCoordinator) {
        _coordinator = State(wrappedValue: coordinator)
    }
    
    var body: some View {
        NavigationStack(path: $coordinator.path) {
            coordinator.buildClassroom()
                .navigationDestination(for: AppRoutes.self) { route in
                    coordinator.buildView(route: route)
                }
        }
    }
}
