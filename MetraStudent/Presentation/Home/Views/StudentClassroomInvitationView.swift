import SwiftUI
import UIKit

struct StudentClassroomInvitationView: View {
    @State private var viewModel: StudentClassroomInvitationViewModel
    @State private var displayName: String
    @State private var isCompletingJoin = false
    let onJoined: (ClassroomChannelModel, String) async -> Void

    init(link: ClassroomInvitationLink, studentName: String,
         onJoined: @escaping (ClassroomChannelModel, String) async -> Void) {
        _viewModel = State(initialValue: StudentClassroomInvitationViewModel(link: link, receiver: CloudKitManager.shared))
        _displayName = State(initialValue: studentName)
        self.onJoined = onJoined
    }

    var body: some View {
        Form {
            if viewModel.isLoading {
                Section {
                    ProgressView("Membuka undangan kelas…")
                        .accessibilityLabel(IndonesianSpeech.text("Membuka undangan kelas"))
                }
            }
            if let invitation = viewModel.invitation {
                Section {
                    LabeledContent { IndonesianSpeech.text(invitation.name) } label: { IndonesianSpeech.text("Kelas") }
                    LabeledContent { IndonesianSpeech.text(invitation.teacherName) } label: { IndonesianSpeech.text("Guru") }
                    LabeledContent { IndonesianSpeech.text(invitation.code) } label: { IndonesianSpeech.text("Kode kelas") }
                } header: {
                    IndonesianSpeech.text("Undangan dari guru")
                } footer: {
                    IndonesianSpeech.text("Bergabung untuk menerima materi yang dibagikan guru di kelas ini.")
                }
                Section {
                    TextField("Nama profil siswa", text: $displayName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .accessibilityLabel(IndonesianSpeech.text("Nama profil siswa"))
                        .disabled(viewModel.isJoining || isCompletingJoin)
                    Button {
                        isCompletingJoin = true
                        Task {
                            defer { isCompletingJoin = false }
                            if let channel = await viewModel.join(displayName: displayName) {
                                await onJoined(channel, displayName.trimmingCharacters(in: .whitespacesAndNewlines))
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if viewModel.isJoining || isCompletingJoin { ProgressView().accessibilityHidden(true) }
                            IndonesianSpeech.text(viewModel.isJoining || isCompletingJoin ? "Sedang bergabung…" : "Gabung kelas")
                        }
                    }
                    .disabled(viewModel.isJoining || isCompletingJoin || viewModel.didJoin || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("student.joinClassroomInvitation")
                } header: { IndonesianSpeech.text("Bergabung sebagai") }
            }
            if let error = viewModel.errorMessage {
                Section {
                    IndonesianSpeech.text(error)
                    if let details = viewModel.errorDetails {
                        DisclosureGroup {
                            Text(details).font(.caption).textSelection(.enabled)
                            Button(indonesian: "Salin detail kesalahan") { UIPasteboard.general.string = details }
                        } label: { IndonesianSpeech.text("Detail untuk pengembang") }
                    }
                    if viewModel.invitation == nil {
                        Button(indonesian: "Coba lagi") { Task { await viewModel.load() } }
                            .disabled(viewModel.isLoading)
                    }
                } header: { IndonesianSpeech.text("Undangan belum bisa diproses") }
            }
        }
        .navigationTitle(IndonesianSpeech.text("Undangan kelas"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.isJoining || isCompletingJoin)
        .task { await viewModel.load() }
        .onChange(of: viewModel.errorMessage) { _, message in
            if let message { IndonesianSpeech.announce(message) }
        }
        .onChange(of: viewModel.invitation?.channelRecordName) { _, recordName in
            if recordName != nil, let invitation = viewModel.invitation {
                IndonesianSpeech.announce("Undangan kelas \(invitation.name) dari \(invitation.teacherName). Isi nama profil, lalu pilih Gabung kelas.")
            }
        }
        .accessibilityIdentifier("student.classroomInvitation")
    }
}
