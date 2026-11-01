//
//  LibraryView.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 29/10/26.
//

import SwiftUI

struct LibraryView: View {
    @Bindable var viewModel: LibraryViewModel
    
    var body: some View {
        List {
            Section {
                if viewModel.materials.isEmpty {
                    Text("Belum ada materi pembelajaran yang disimpan")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                        .accessibilityLabel("Belum ada materi pembelajaran yang disimpan di pustaka.")
                } else if viewModel.filteredMaterials.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                } else {
                    ForEach(viewModel.filteredMaterials) { material in
                        Button {
                            viewModel.openMaterialDetail(material)
                        } label: {
                            HStack {
                                Text(material.title)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Materi tersimpan: \(material.title)")
                        .accessibilityHint("Ketuk dua kali untuk membuka detail materi pembelajaran")
                    }
                    .onDelete { offsets in
                        viewModel.deleteMaterial(at: offsets)
                    }
                }
            } header: {
                Text("Materi Tersimpan")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .textCase(nil)
                    .listRowInsets(EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0))
            }
            .headerProminence(.increased)
        }
        .navigationTitle("Pustaka")
        .searchable(
            text: $viewModel.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Cari judul materi..."
        )
        .onAppear {
            viewModel.loadMaterials()
        }
    }
}

#Preview {
    let coordinator = AppCoordinator.makePreview()
    return NavigationStack {
        coordinator.buildLibrary()
            .navigationDestination(for: AppRoutes.self) { route in
                coordinator.buildDestination(for: route)
            }
    }
}
