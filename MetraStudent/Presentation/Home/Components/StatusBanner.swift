//
//  StatusBanner.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 08/11/26.
//

import SwiftUI

struct StatusBanner: View {
    let message: String
    var body: some View {
        IndonesianSpeech.text(message)
            .font(AppTypography.body)
            .foregroundStyle(AppColor.secondaryText)
            .padding(AppSize.Inset.page)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            .metraCard(radius: AppSize.Radius.assistantCard, border: .clear)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

#Preview {
    List {
        StatusBanner(message: "“Foto 8 Nov” sudah tersimpan.")
        StatusBanner(message: "Fitur AI belum tersedia di perangkat ini.")
    }
    .listStyle(.insetGrouped)
}
