import Foundation

struct ReceivedClassroomInvitation: Equatable, Sendable {
    let link: ClassroomInvitationLink
    let channelRecordName: String
    let code: String
    let name: String
    let teacherName: String
}

@MainActor
protocol ClassroomInvitationReceiving {
    func previewInvitation(_ link: ClassroomInvitationLink) async throws -> ReceivedClassroomInvitation
    func joinInvitation(_ invitation: ReceivedClassroomInvitation, displayMember: String) async throws -> ClassroomChannelModel
}
