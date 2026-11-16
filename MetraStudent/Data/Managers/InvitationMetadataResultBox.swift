import CloudKit
import Foundation

/// CloudKit invokes its result callbacks outside the app's main actor.
final class InvitationMetadataResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Result<CKShare.Metadata, Error>?

    func store(_ result: Result<CKShare.Metadata, Error>) {
        lock.lock()
        defer { lock.unlock() }
        value = result
    }

    func result() -> Result<CKShare.Metadata, Error>? {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}
