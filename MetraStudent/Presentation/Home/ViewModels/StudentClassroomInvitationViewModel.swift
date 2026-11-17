import Foundation
import Observation

@Observable @MainActor
final class StudentClassroomInvitationViewModel {
    let link: ClassroomInvitationLink
    private(set) var invitation: ReceivedClassroomInvitation?
    private(set) var isLoading = false
    private(set) var isJoining = false
    private(set) var didJoin = false
    var errorMessage: String?
    private(set) var errorDetails: String?
    private let receiver: any ClassroomInvitationReceiving

    init(link: ClassroomInvitationLink, receiver: any ClassroomInvitationReceiving) {
        self.link = link
        self.receiver = receiver
    }

    func load() async {
        guard !isLoading, !isJoining, invitation == nil else { return }
        isLoading = true
        errorMessage = nil
        errorDetails = nil
        defer { isLoading = false }
        do {
            let preview = try await receiver.previewInvitation(link)
            try Task.checkCancellation()
            invitation = preview
        } catch is CancellationError {} catch {
            if !Task.isCancelled { show(error) }
        }
    }

    func join(displayName: String) async -> ClassroomChannelModel? {
        guard !isJoining, !didJoin, let invitation else { return nil }
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { errorMessage = "Isi nama profil sebelum bergabung ke kelas."; return nil }
        isJoining = true
        errorMessage = nil
        errorDetails = nil
        defer { isJoining = false }
        do {
            let channel = try await receiver.joinInvitation(invitation, displayMember: name)
            didJoin = true
            return channel
        } catch { show(error); return nil }
    }

    private func show(_ error: Error) {
        if let error = error as? StudentClassroomInvitationFailure {
            errorMessage = error.errorDescription
            errorDetails = error.diagnosticDetails
        } else if let error = error as? ClassroomInvitationValidationError {
            errorMessage = error.errorDescription
            errorDetails = error.diagnosticDetails
        } else if let error = error as? ClassroomInvitationError {
            errorMessage = error.errorDescription ?? "Undangan belum bisa dibuka."
        } else {
            errorMessage = "Undangan kelas belum bisa diproses. Periksa akun iCloud dan koneksi internet, lalu coba lagi."
            let failure = error as NSError
            errorDetails = "Error: \(failure.domain) (\(failure.code))\nApp: \(Bundle.main.bundleIdentifier ?? "tidak diketahui")\nContainer: \(ClassroomInvitationContract.containerIdentifier ?? "default dari entitlements aplikasi")"
        }
    }
}
