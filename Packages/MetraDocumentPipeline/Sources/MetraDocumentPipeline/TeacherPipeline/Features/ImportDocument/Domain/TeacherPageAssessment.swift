#if os(iOS)
import Foundation

nonisolated struct TeacherPageAssessment: Identifiable, Equatable, Sendable {
    enum Status: String, Codable, Sendable { case ready, needsAttention, unreadable, processingFailed }
    enum Stage: Equatable, Sendable { case inspection, conversion }
    let id: UUID
    let status: Status
    var stage: Stage = .inspection
    let message: String

    var canConvert: Bool { status == .ready || status == .needsAttention }
    var title: String {
        switch status {
        case .ready: "Halaman sudah diperiksa"
        case .needsAttention: "Periksa gambar ini"
        case .unreadable: "Halaman belum dapat dibaca"
        case .processingFailed: "Halaman belum dapat diproses"
        }
    }
}

#endif
