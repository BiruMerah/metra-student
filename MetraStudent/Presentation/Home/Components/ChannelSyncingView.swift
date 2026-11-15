//
//  ChannelSyncingView.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 08/11/26.
//

import SwiftUI

struct ChannelSyncingView: View {
    var body: some View {
        HStack(spacing: AppSize.Spacing.medium) {
            ProgressView()
                .controlSize(.regular)
                .accessibilityHidden(true)
            IndonesianSpeech.text("Menyinkronkan kelas…")
                .font(AppTypography.headline)
                .foregroundStyle(.primary)
        }
        .padding(AppSize.Spacing.large)
        .frame(maxWidth: .infinity, minHeight: AppSize.Height.documentRow, alignment: .leading)
        .metraCard(radius: AppSize.Radius.assistantCard, border: AppColor.brand.opacity(0.18))
    }
}

#Preview {
    List {
        Section {
            ChannelSyncingView()
        }
    }
}
