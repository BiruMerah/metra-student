//
//  MaterialDetailView.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 29/10/26.
//

import SwiftUI

struct MaterialDetailView: View {
    var body: some View {
        VStack {
            Text("Hello, This is MaterialDetailView!")
        }
        .navigationTitle("Detail Materi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

#Preview {
    MaterialDetailView()
}
