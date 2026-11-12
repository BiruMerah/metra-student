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
                IndonesianSpeech.text(viewModel.material.title)
                    .font(AppTypography.contentTitle)
                    .accessibilityAddTraits(.isHeader)
                    .textSelection(.enabled)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
            }
            
            Section {
                MaterialOverviewView(overview: viewModel.overview)
            } header: {
                IndonesianSpeech.text("Ringkasan Materi")
                    .font(AppTypography.headline)
                    .textCase(nil)
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
                IndonesianSpeech.text("Segmen")
                    .font(AppTypography.headline)
                    .textCase(nil)
            } footer: {
                IndonesianSpeech.text("Pilih segmen untuk melihat detailnya.")
                    .font(AppTypography.supporting)
            }

            if viewModel.isSaved {
                Section {
                    Button {
                        confirmsMaterialDeletion = true
                    } label: {
                        Label(indonesian: "Hapus Materi", systemImage: "trash")
                            .font(AppTypography.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .buttonBorderShape(.capsule)
                    .tint(AppColor.danger)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.horizontal, AppSize.Inset.page, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle(IndonesianSpeech.text("Detail Materi"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            viewModel.checkSavedStatus()
        }
        .alert(IndonesianSpeech.text("Hapus Materi?"), isPresented: $confirmsMaterialDeletion) {
            Button(indonesian: "Batal", role: .cancel) {}
            Button(indonesian: "Hapus Materi", role: .destructive) {
                viewModel.removeSavedMaterial()
            }
        } message: {
            IndonesianSpeech.text("Materi “\(viewModel.material.title)” akan dihapus dari Dokumen Tersimpan.")
        }
        .alert(IndonesianSpeech.text("Terjadi Kesalahan"), isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(indonesian: "Tutup", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            IndonesianSpeech.text(viewModel.errorMessage ?? "")
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
