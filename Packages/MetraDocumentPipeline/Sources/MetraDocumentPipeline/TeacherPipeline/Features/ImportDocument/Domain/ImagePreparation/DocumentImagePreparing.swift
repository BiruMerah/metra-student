#if os(iOS)
import Foundation

/// Runs before page inspection and layout extraction; one capture can yield many pages.
protocol DocumentImagePreparing: Sendable {
    func prepare(_ inputs: [MaterialImageInput], remainingPages: Int) async throws -> [MaterialImageInput]
}

struct DocumentImagePreparation: Sendable {
    enum Outcome: Sendable, Equatable { case corrected, split, needsReview }
    let sourceID: UUID
    let originalData: Data
    let originalFileName: String
    let outcome: Outcome
    let pageNumber: Int
    let pageCount: Int
    let boundary: DocumentQuadrilateral?
    let explanation: String?
}

enum DocumentImagePreparationError: TeacherUserFacingError {
    case pageLimit(found: Int, available: Int)
    case unreadableImage
    var errorDescription: String? {
        switch self {
        case .pageLimit(let found, let available):
            return "Sedikitnya \(found) halaman terdeteksi, tetapi hanya tersisa \(available) halaman. Maksimal 10 halaman per dokumen. Pilih lebih sedikit foto atau ambil foto satu lembar per gambar."
        case .unreadableImage: return "Gambar belum dapat disiapkan. Coba pilih ulang atau ambil foto kembali."
        }
    }
}

#endif
