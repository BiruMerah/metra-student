//
//  ChannelView.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 06/11/26.
//

import SwiftUI

struct ChannelView: View {
    @Bindable var viewModel: ChannelViewModel
    
    var body: some View {
        List {
            Section {
                Text("Fitur channel belum tersedia")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
        }
        .navigationTitle("Channel")
    }
}

#Preview {
    let coordinator = AppCoordinator.makePreview()
    return NavigationStack {
        coordinator.buildChannel()
            .navigationDestination(for: AppRoutes.self) { route in
                coordinator.buildDestination(for: route)
            }
    }
}
