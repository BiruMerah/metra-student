#if os(iOS)
import Foundation

struct MaterialImageInput: Identifiable, Sendable {
    enum Origin: Sendable {
        case photoLibrary, camera, files
        #if DEBUG
        case verificationFixture(URL)
        #endif
    }

    let id: UUID
    let data: Data
    let fileName: String
    let origin: Origin
    let preparation: DocumentImagePreparation?

    init(data: Data, fileName: String, origin: Origin, preparation: DocumentImagePreparation? = nil) {
        id = UUID()
        self.data = data
        self.fileName = fileName
        self.origin = origin
        self.preparation = preparation
    }
}

#endif
