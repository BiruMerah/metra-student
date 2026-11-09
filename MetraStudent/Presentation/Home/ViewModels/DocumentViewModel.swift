import Foundation
import Observation

@Observable
@MainActor
final class DocumentViewModel {
    private let mathMaterialRepository: MathMaterialProtocol
    private let storageIsPersistent: Bool
    private let notificationManager: NotificationProtocol?
    weak var coordinator: AppCoordinator?

    @ObservationIgnored private var importTask: Task<Void, Never>?
    private(set) var savedMaterials: [MathMaterialModel] = []
    private(set) var progress: String?
    private(set) var isCancelling = false
    private(set) var successMessage: String?
    var errorMessage: String?

    var importUnavailableReason: String? {
        if !DocumentConverter.isSupported { return "Impor dokumen tersedia di iPhone dan iPad." }
        if !storageIsPersistent { return "Penyimpanan dokumen tidak tersedia. Coba buka ulang aplikasi." }
        return nil
    }

    var canImport: Bool { importUnavailableReason == nil && progress == nil }

    init(
        mathMaterialRepository: MathMaterialProtocol,
        storageIsPersistent: Bool = true,
        notificationManager: NotificationProtocol? = nil,
        coordinator: AppCoordinator? = nil
    ) {
        self.mathMaterialRepository = mathMaterialRepository
        self.storageIsPersistent = storageIsPersistent
        self.notificationManager = notificationManager
        self.coordinator = coordinator
    }

    func reload() {
        do {
            savedMaterials = try mathMaterialRepository.fetchSavedMaterials()
        } catch {
            errorMessage = "Daftar dokumen belum dapat dimuat. Coba buka kembali tab Dokumen."
        }
    }

    func importDocument(from url: URL) {
        startImport(progress: "Membuka PDF…") { onProgress in
            try await DocumentConverter.convert(url, onProgress: onProgress)
        }
    }

    func importPhoto(loadData: @escaping @MainActor () async throws -> Data?) {
        startImport(progress: "Mengambil foto dari galeri…") { onProgress in
            let data: Data
            do {
                guard let photo = try await loadData() else { throw PhotoImportError.unreadable }
                data = photo
            } catch {
                try Task.checkCancellation()
                throw PhotoImportError.unreadable
            }
            try Task.checkCancellation()
            let date = Date.now.formatted(
                .dateTime.day().month(.abbreviated).year().hour().minute().locale(Locale(identifier: "id_ID"))
            )
            return try await DocumentConverter.convertPhoto(data, title: "Foto \(date)", onProgress: onProgress)
        }
    }

    private func startImport(
        progress initialProgress: String,
        convert: @escaping @MainActor (@escaping @MainActor (String) -> Void) async throws -> MathMaterialModel
    ) {
        guard canImport else { return }
        successMessage = nil
        errorMessage = nil
        progress = initialProgress
        notificationManager?.announceAccessibility(initialProgress)
        importTask = Task { [weak self] in
            guard let self else { return }
            defer {
                progress = nil
                importTask = nil
                isCancelling = false
                if Task.isCancelled {
                    notificationManager?.announceAccessibility("Penambahan dokumen dibatalkan.")
                }
            }

            let material: MathMaterialModel
            do {
                material = try await convert { [weak self] message in
                    guard !Task.isCancelled else { return }
                    self?.progress = message
                }
                try Task.checkCancellation()
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? "Dokumen belum dapat dikonversi. Periksa berkas lalu coba lagi."
                return
            }

            progress = "Menyimpan dokumen…"
            do {
                try mathMaterialRepository.saveMaterial(material)
            } catch {
                errorMessage = "Dokumen sudah dikonversi, tetapi belum tersimpan. Periksa ruang penyimpanan lalu coba lagi."
                return
            }
            savedMaterials.removeAll { $0.id == material.id }
            savedMaterials.append(material)
            savedMaterials.sort { $0.createdAt > $1.createdAt }
            successMessage = "“\(material.title)” sudah tersimpan."
            notificationManager?.announceAccessibility("Dokumen berhasil disimpan.")
        }
    }

    func cancelImport() {
        guard let importTask, !isCancelling else { return }
        importTask.cancel()
        isCancelling = true
        progress = "Membatalkan penambahan dokumen…"
    }

    func deleteMaterials(ids: Set<UUID>) -> Bool {
        let count = savedMaterials.count(where: { ids.contains($0.id) })
        guard count > 0 else { return false }
        do {
            try mathMaterialRepository.deleteMaterials(ids: ids)
        } catch {
            errorMessage = "Dokumen belum dapat dihapus. Coba lagi."
            return false
        }
        savedMaterials.removeAll { ids.contains($0.id) }
        successMessage = nil
        notificationManager?.announceAccessibility(count == 1 ? "Dokumen dihapus." : "\(count) dokumen dihapus.")
        return true
    }

    func announceSelectionMode(_ isSelecting: Bool) {
        notificationManager?.announceAccessibility(isSelecting
            ? "Mode pilih aktif. Ketuk dua kali pada dokumen untuk memilih."
            : "Mode pilih selesai.")
    }

    private enum PhotoImportError: LocalizedError {
        case unreadable

        var errorDescription: String? { "Foto belum dapat dibuka. Coba pilih foto lain." }
    }

    func open(_ material: MathMaterialModel) {
        successMessage = nil
        coordinator?.navigate(to: .material(material))
    }

    func clearSuccessMessage() {
        successMessage = nil
    }
}
