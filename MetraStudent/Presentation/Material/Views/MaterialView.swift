//
//  MaterialView.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 09/11/26.
//

import SwiftUI

struct MaterialView: View {
    @Bindable var viewModel: MaterialViewModel
    @State private var confirmsDocumentDeletion = false
    
    var body: some View {
        List {
            Section {
                Text(viewModel.material.title)
                    .font(.title.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                    .textSelection(.enabled)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
            }
            
            Section("Overview") {
                MaterialOverviewView(overview: viewModel.overview)
            }
            
            Section {
                ForEach(Array(viewModel.sections.enumerated()), id: \.element.id) { index, section in
                    MaterialSectionRow(
                        section: section,
                        index: index,
                        onTap: {
                            viewModel.openSection(at: index)
                        }
                    )
                }
            } header: {
                Text("Segmen")
            } footer: {
                Text("Pilih segmen untuk melihat detailnya.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Detail Materi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    confirmsDocumentDeletion = true
                } label: {
                    Label("Hapus Dokumen", systemImage: "trash")
                }
            }
        }
        .onAppear {
            viewModel.checkSavedStatus()
        }
        .alert("Hapus Dokumen?", isPresented: $confirmsDocumentDeletion) {
            Button("Batal", role: .cancel) {}
            Button("Hapus Dokumen", role: .destructive) {
                viewModel.removeSavedMaterial()
            }
        } message: {
            Text("Materi “\(viewModel.material.title)” akan dihapus dari Dokumen Tersimpan.")
        }
        .alert("Terjadi Kesalahan", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

#Preview {
    let coordinator = AppCoordinator.makePreview()
    let sampleMaterial = MathMaterialModel(
        title: "Persamaan Linear Satu Variabel",
        category: "Aljabar",
        content: "Contoh isi materi pembelajaran dari guru.",
        overview: MaterialOverview.sample.summaryText,
        sections: MathSectionModel.sampleSections
    )
    return NavigationStack(path: Bindable(coordinator).channelPath) {
        MaterialView(
            viewModel: MaterialViewModel(
                material: sampleMaterial,
                mathMaterialRepository: coordinator.mathMaterialRepository,
                notificationManager: coordinator.notificationManager,
                coordinator: coordinator
            )
        )
        .navigationDestination(for: AppRoutes.self) { route in
            coordinator.buildDestination(for: route)
        }
    }
}
