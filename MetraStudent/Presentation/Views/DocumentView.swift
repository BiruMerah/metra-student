import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct DocumentView: View {
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
            importStatus

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
                } else {
                    ContentUnavailableView(
                        "Dokumen tidak ditemukan",
                        systemImage: "magnifyingglass",
                        description: Text("Coba cari dengan judul lain.")
                    )
                }
            } else {
                Section("Terbaru") {
                    ForEach(matchingDocuments) { material in
                        documentRow(material)
                    }
                }
            }
        }
        .listStyle(.plain)
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
            if isSelecting { selectionBar }
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

    private var addDocumentMenu: some View {
        Menu {
            Button("Pilih dari Galeri", systemImage: "photo") { showsPhotoPicker = true }
            Button("Pilih PDF", systemImage: "doc") { showsPDFPicker = true }
        } label: {
            Label("Tambah Dokumen", systemImage: "plus")
        }
        .disabled(!viewModel.canImport)
        .accessibilityHint("Pilih foto dari galeri atau berkas PDF")
    }

    @ViewBuilder
    private var importStatus: some View {
        if let reason = viewModel.importUnavailableReason {
            Text(reason).foregroundStyle(.secondary)
        } else if let progress = viewModel.progress {
            Section {
                ProgressView { Text(progress) }
                Button("Batalkan Penambahan", role: .cancel, action: viewModel.cancelImport)
                    .disabled(viewModel.isCancelling)
            }
        } else if let message = viewModel.successMessage {
            Label(message, systemImage: "checkmark.circle")
        }
    }

    private var selectionBar: some View {
        VStack(spacing: 8) {
            Text(selectionSummary)
                .font(.subheadline)
                .multilineTextAlignment(.center)

            Button(role: .destructive) {
                pendingDeletion = viewModel.savedMaterials.filter { selectedIDs.contains($0.id) }
            } label: {
                Label("Hapus Dokumen Terpilih", systemImage: "trash")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedIDs.isEmpty)
            .accessibilityHint("Meminta konfirmasi sebelum menghapus")
        }
        .padding()
        .background(.regularMaterial)
    }

    @ViewBuilder
    private func documentRow(_ material: MathMaterialModel) -> some View {
        if isSelecting {
            let isSelected = selectedIDs.contains(material.id)
            rowButton(material, icon: isSelected ? "checkmark.circle.fill" : "circle") {
                if isSelected { selectedIDs.remove(material.id) }
                else { selectedIDs.insert(material.id) }
            }
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityHint(isSelected ? "Batalkan pilihan dokumen ini" : "Pilih dokumen ini")
        } else {
            rowButton(material, icon: "doc.text") { viewModel.open(material) }
                .accessibilityHint("Buka detail dokumen")
                .contextMenu {
                    Button("Hapus Dokumen", systemImage: "trash", role: .destructive) {
                        pendingDeletion = [material]
                    }
                }
                .accessibilityAction(named: Text("Hapus Dokumen")) {
                    pendingDeletion = [material]
                }
        }
    }

    private func rowButton(_ material: MathMaterialModel, icon: String, action: @escaping () -> Void) -> some View {
        let date = material.createdAt.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "id_ID")))
        return Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(material.title).font(.body)
                    Text(date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(material.title))
        .accessibilityValue(Text(date))
    }

    private func setSelectionMode(_ enabled: Bool, announces: Bool = true) {
        isSelecting = enabled
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
