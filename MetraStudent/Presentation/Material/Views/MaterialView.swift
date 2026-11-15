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
        ScrollView {
            VStack(alignment: .leading, spacing: AppSize.Inset.sheet) {
                IndonesianSpeech.text(viewModel.material.title)
                    .font(AppTypography.contentTitle)
                    .accessibilityAddTraits(.isHeader)
                    .textSelection(.enabled)

                VStack(alignment: .leading, spacing: AppSize.Spacing.small) {
                    IndonesianSpeech.text("Ringkasan Materi")
                        .font(AppTypography.headline)
                        .accessibilityAddTraits(.isHeader)
                    MaterialOverviewView(overview: viewModel.overview)
                }

                VStack(alignment: .leading, spacing: AppSize.Spacing.small) {
                    IndonesianSpeech.text("Segmen")
                        .font(AppTypography.headline)
                        .accessibilityAddTraits(.isHeader)
                    if !viewModel.sections.isEmpty {
                        sectionRows
                    }
                    IndonesianSpeech.text("Pilih segmen untuk melihat detailnya.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.secondaryText)
                        .padding(.top, AppSize.Spacing.small)
                }

                if viewModel.isSaved {
                    Button {
                        confirmsMaterialDeletion = true
                    } label: {
                        IndonesianSpeech.text("Hapus Materi")
                    }
                    .buttonStyle(MetraActionStyle(appearance: .destructive))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSize.Inset.page)
            .padding(.top, AppSize.Spacing.large)
            .padding(.bottom, AppSize.Inset.sheet)
        }
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle(IndonesianSpeech.text("Detail Materi"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
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

    private var sectionRows: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.sections.enumerated()), id: \.element.id) { index, section in
                if index > 0 {
                    Divider()
                        .padding(.horizontal, AppSize.Inset.page)
                        .accessibilityHidden(true)
                }

                MaterialSectionRow(section: section, index: index) {
                    viewModel.openSection(at: index)
                }
            }
        }
        .metraCard()
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
