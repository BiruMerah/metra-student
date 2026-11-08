//
//  DocumentView.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 08/11/26.
//

import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct DocumentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var viewModel: DocumentViewModel
    
    @State private var searchText = ""
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var pendingDeletion: [MathMaterialModel]?
    @State private var showsPDFPicker = false
    @State private var showsPhotoPicker = false
    @State private var photo: PhotosPickerItem?

    private var matchingDocuments: [MathMaterialModel] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return viewModel.savedMaterials }
        return viewModel.savedMaterials.filter { $0.title.localizedStandardContains(query) }
    }

    private var selectionSummary: String {
        let visibleCount = matchingDocuments.count { selectedIDs.contains($0.id) }
        let hiddenCount = selectedIDs.count - visibleCount
        let count = "\(selectedIDs.count) dokumen dipilih"
        return hiddenCount > 0 ? "\(count), \(hiddenCount) di luar hasil pencarian" : count
    }

    var body: some View {
        List {
            ImportStatusSection(
                unavailableReason: viewModel.importUnavailableReason,
                progress: viewModel.progress,
                isCancelling: viewModel.isCancelling,
                successMessage: viewModel.successMessage,
                onCancel: viewModel.cancelImport
            )

            if matchingDocuments.isEmpty {
                if viewModel.savedMaterials.isEmpty {
                    ContentUnavailableView {
                        Label("Belum ada dokumen", systemImage: "doc.text")
                    } description: {
                        if viewModel.importUnavailableReason == nil {
                            Text("Pilih foto atau PDF untuk mulai.")
                        }
                    } actions: {
                        if viewModel.importUnavailableReason == nil {
                            addDocumentMenu
                                .labelStyle(.titleAndIcon)
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                        }
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ContentUnavailableView(
                        "Dokumen tidak ditemukan",
                        systemImage: "magnifyingglass",
                        description: Text("Coba cari dengan judul lain.")
                    )
                    .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(matchingDocuments) { material in
                        DocumentRow(
                            material: material,
                            isSelected: isSelecting ? selectedIDs.contains(material.id) : nil,
                            onTap: { handleTap(on: material) },
                            onDelete: { pendingDeletion = [material] }
                        )
                    }
                } header: {
                    Text("Terbaru · \(matchingDocuments.count)")
                        .accessibilityLabel(Text("Terbaru, \(matchingDocuments.count) dokumen"))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Dokumen")
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Cari judul dokumen")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if isSelecting {
                    Button("Selesai") { setSelectionMode(false) }
                        .accessibilityHint("Keluar dari mode pilih")
                } else {
                    Button("Pilih") { setSelectionMode(true) }
                        .disabled(matchingDocuments.isEmpty)
                        .accessibilityHint("Pilih beberapa dokumen untuk dihapus")

                    addDocumentMenu
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isSelecting {
                SelectionBar(summary: selectionSummary, canDelete: !selectedIDs.isEmpty) {
                    pendingDeletion = viewModel.savedMaterials.filter { selectedIDs.contains($0.id) }
                }
            }
        }
        .onAppear(perform: viewModel.reload)
        .onChange(of: viewModel.savedMaterials.map(\.id)) { _, availableIDs in
            selectedIDs.formIntersection(availableIDs)
            if isSelecting && availableIDs.isEmpty { setSelectionMode(false, announces: false) }
        }
        .photosPicker(isPresented: $showsPhotoPicker, selection: $photo, matching: .images, preferredItemEncoding: .current)
        .onChange(of: photo) { _, item in
            guard let item else { return }
            photo = nil
            viewModel.importPhoto { try await item.loadTransferable(type: Data.self) }
        }
        .fileImporter(isPresented: $showsPDFPicker, allowedContentTypes: [.pdf]) { result in
            switch result {
            case .success(let url): viewModel.importDocument(from: url)
            case .failure: viewModel.errorMessage = "PDF belum dapat dibuka. Coba pilih ulang."
            }
        }
        .alert("Hapus Dokumen?", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        ), presenting: pendingDeletion) { materials in
            Button("Batal", role: .cancel) {}
            Button(materials.count == 1 ? "Hapus Dokumen" : "Hapus \(materials.count) Dokumen", role: .destructive) {
                let ids = Set(materials.map(\.id))
                if viewModel.deleteMaterials(ids: ids), isSelecting {
                    setSelectionMode(false, announces: false)
                }
            }
        } message: { materials in
            if materials.count == 1, let material = materials.first {
                Text("“\(material.title)” akan dihapus dari Metra.")
            } else {
                Text("\(materials.count) dokumen yang dipilih akan dihapus dari Metra.")
            }
        }
        .alert("Terjadi Kesalahan", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    /// Used twice (empty state + toolbar), so kept as a small shortcut.
    private var addDocumentMenu: some View {
        AddDocumentMenu(
            isEnabled: viewModel.canImport,
            onPickPhoto: { showsPhotoPicker = true },
            onPickPDF: { showsPDFPicker = true }
        )
    }

    private func handleTap(on material: MathMaterialModel) {
        guard isSelecting else {
            viewModel.open(material)
            return
        }
        if selectedIDs.contains(material.id) { selectedIDs.remove(material.id) }
        else { selectedIDs.insert(material.id) }
    }

    private func setSelectionMode(_ enabled: Bool, announces: Bool = true) {
        withAnimation(reduceMotion ? nil : .snappy) {
            isSelecting = enabled
        }
        selectedIDs.removeAll()
        if announces { viewModel.announceSelectionMode(enabled) }
    }
}

#Preview {
    let coordinator = AppCoordinator.makePreview()
    NavigationStack {
        coordinator.buildDocument()
            .navigationDestination(for: AppRoutes.self) { route in
                coordinator.buildDestination(for: route, in: .document)
            }
    }
}
