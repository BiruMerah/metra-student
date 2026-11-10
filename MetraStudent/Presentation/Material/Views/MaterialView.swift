//
//  MaterialView.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 09/11/26.
//

import SwiftUI

struct MaterialView: View {
    @Bindable var viewModel: MaterialViewModel
    @State private var confirmsMaterialDeletion = false
    
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

            if viewModel.isSaved {
                Section {
                    Button {
                        confirmsMaterialDeletion = true
                    } label: {
                        Label("Hapus Materi", systemImage: "trash")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 16))
                    .tint(Color(red: 0.74, green: 0.12, blue: 0.16))
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Detail Materi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            viewModel.checkSavedStatus()
        }
        .alert("Hapus Materi?", isPresented: $confirmsMaterialDeletion) {
            Button("Batal", role: .cancel) {}
            Button("Hapus Materi", role: .destructive) {
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
    let sampleMaterial = MathMaterialModel(
        title: "Persamaan Linear Satu Variabel",
        category: "Aljabar",
        content: "Contoh isi materi pembelajaran dari guru.",
        overview: MaterialOverview.sample.summaryText,
        sections: MathSectionModel.sampleSections
    )
    let coordinator = AppCoordinator.makePreview(savedMaterials: [sampleMaterial])
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
