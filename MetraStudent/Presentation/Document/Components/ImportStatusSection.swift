//
//  ImportStatusSection.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 08/11/26.
//

import SwiftUI

/// Shows at most one status at the top of the document list:
/// import unavailable → converting → success.
struct ImportStatusSection: View {
    let unavailableReason: String?
    let progress: String?
    let isCancelling: Bool
    let successMessage: String?
    let onCancel: () -> Void

    var body: some View {
        if let unavailableReason {
            Section {
                StatusBanner(message: unavailableReason, systemImage: "exclamationmark.triangle.fill", tint: .orange)
            }
        } else if let progress {
            Section {
                ImportProgressCard(progress: progress, isCancelling: isCancelling, onCancel: onCancel)
            }
        } else if let successMessage {
            Section {
                StatusBanner(message: successMessage, systemImage: "checkmark.circle.fill", tint: .green)
            }
        }
    }
}

#Preview {
    List {
        ImportStatusSection(unavailableReason: nil, progress: "Membaca halaman 2 dari 5…", isCancelling: false, successMessage: nil, onCancel: {})
        ImportStatusSection(unavailableReason: nil, progress: nil, isCancelling: false, successMessage: "“Foto 8 Nov” sudah tersimpan.", onCancel: {})
        ImportStatusSection(unavailableReason: "Fitur AI belum tersedia di perangkat ini.", progress: nil, isCancelling: false, successMessage: nil, onCancel: {})
    }
    .listStyle(.insetGrouped)
}
