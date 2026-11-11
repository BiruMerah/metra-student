//
//  MaterialOverviewView.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 10/11/26.
//

import SwiftUI

struct MaterialOverviewView: View {
    let overview: MaterialOverview
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let summary = overview.summaryText,
               !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                IndonesianSpeech.text(summary)
                    .font(AppTypography.readingBody)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                if !overview.pageLabels.isEmpty {
                    overviewLine("Halaman", value: overview.pageLabels.joined(separator: ", "))
                }
            } else {
                overviewLine("Bab", value: overview.chapter)
                overviewLine("Subbab", value: overview.subchapter)
                overviewLine("Halaman", value: overview.pageNumber.formatted(.number.locale(IndonesianSpeech.locale)))
            }
        }
        .padding(.vertical, 6)
    }

    private func overviewLine(_ title: String, value: String) -> some View {
        IndonesianSpeech.text("\(title): \(value)")
            .font(AppTypography.body)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
            .accessibilityLabel(IndonesianSpeech.text("\(title), \(value)"))
    }
}

#Preview {
    List {
        Section {
            MaterialOverviewView(overview: MaterialOverview.sample)
        } header: {
            IndonesianSpeech.text("Ringkasan Materi")
                .font(AppTypography.headline)
                .textCase(nil)
        }
    }
    .listStyle(.insetGrouped)
}
