//
//  MaterialDetailView.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 29/10/26.
//

import SwiftUI

struct MaterialDetailView: View {
    @Bindable var viewModel: MaterialDetailViewModel
    var sourceTab: AppTab = .channel
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
                overviewContent
            }

            Section {
                ForEach(Array(viewModel.sections.enumerated()), id: \.element.id) { index, section in
                    Button {
                        viewModel.openSection(at: index)
                    } label: {
                        sectionRow(section, index: index)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Segmen \(index + 1), \(section.title)")
                    .accessibilityHint("Buka detail topik")
                }
            } header: {
                Text("Topik")
            } footer: {
                Text("Pilih topik untuk melihat detailnya.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Detail Materi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if sourceTab == .document {
                    if viewModel.isSaved {
                        Button(role: .destructive) {
                            confirmsDocumentDeletion = true
                        } label: {
                            Label("Hapus Dokumen", systemImage: "trash")
                        }
                    }
                } else if viewModel.isSaved {
                    Menu {
                        Button(role: .destructive) {
                            viewModel.removeSavedMaterial(from: sourceTab)
                        } label: {
                            Label("Hapus dari Pustaka", systemImage: "bookmark.slash")
                        }
                    } label: {
                        Label("Materi Tersimpan", systemImage: "bookmark.fill")
                    }
                    .accessibilityHint("Buka pilihan materi tersimpan")
                } else {
                    Button {
                        viewModel.saveMaterial()
                    } label: {
                        Label("Simpan ke Pustaka", systemImage: "bookmark")
                    }
                    .disabled(!viewModel.canSave)
                }
            }
        }
        .onAppear {
            viewModel.checkSavedStatus()
        }
        .alert("Hapus Dokumen?", isPresented: $confirmsDocumentDeletion) {
            Button("Batal", role: .cancel) {}
            Button("Hapus Dokumen", role: .destructive) {
                viewModel.removeSavedMaterial(from: .document)
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

    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let summary = viewModel.overview.summaryText,
               !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(summary)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                if !viewModel.overview.pageLabels.isEmpty {
                    overviewLine("Halaman", value: viewModel.overview.pageLabels.joined(separator: ", "))
                }
            } else {
                overviewLine("Bab", value: viewModel.overview.chapter)
                overviewLine("Subbab", value: viewModel.overview.subchapter)
                overviewLine("Halaman", value: viewModel.overview.pageNumber.formatted())
            }
        }
        .padding(.vertical, 6)
    }

    private func overviewLine(_ title: String, value: String) -> some View {
        Text("\(title): \(value)")
            .font(.body)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
            .accessibilityLabel("\(title), \(value)")
    }

    @ViewBuilder
    private var overviewCounts: some View {
        countBadge("\(viewModel.sections.count) Topik", symbol: "list.bullet")
            .accessibilityLabel("\(viewModel.sections.count) topik pembelajaran")
        countBadge("\(viewModel.overview.questionCount) Soal", symbol: "questionmark.circle")
            .accessibilityLabel("\(viewModel.overview.questionCount) soal latihan")
    }

    private func countBadge(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.06), in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
    }

    private func sectionRow(_ section: MathSectionModel, index: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 52, height: 52)
                .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(section.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .alignmentGuide(.listRowSeparatorLeading) { dimensions in
            dimensions[.leading] + 64
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
        MaterialDetailView(
            viewModel: MaterialDetailViewModel(
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
