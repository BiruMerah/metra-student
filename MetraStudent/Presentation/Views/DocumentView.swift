//
//  DocumentView.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 06/11/26.
//

import SwiftUI

struct DocumentView: View {
    @Bindable var viewModel: DocumentViewModel
    
    var body: some View {
        List {
            Section {
                Text("Fitur tambah document belum tersedia")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
        }
        .navigationTitle("Document")
    }
}

#Preview {
    let coordinator = AppCoordinator.makePreview()
    return NavigationStack {
        coordinator.buildDocument()
            .navigationDestination(for: AppRoutes.self) { route in
                coordinator.buildDestination(for: route)
            }
    }
}
