//
//  MaterialDetailView.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 29/10/26.
//

import SwiftUI
import SwiftData

struct MaterialDetailView: View {
    @Bindable var viewModel: MaterialDetailViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(viewModel.material.title)
                    .font(.title2.weight(.bold))
                
                Text(viewModel.material.content)
                    .font(.body)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("Detail Materi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.isSaved {
                    Button(role: .destructive) {
                        viewModel.unsaveMaterial()
                    } label: {
                        Text("Hapus")
                            .fontWeight(.semibold)
                            .foregroundStyle(.red)
                    }
                    .accessibilityLabel("Hapus materi tersimpan dari pustaka")
                    .accessibilityHint("Ketuk dua kali untuk menghapus materi ini dari pustaka")
                } else if viewModel.canSave {
                    Button {
                        viewModel.saveMaterial()
                    } label: {
                        Text("Simpan")
                            .fontWeight(.semibold)
                    }
                    .accessibilityLabel("Simpan materi ke pustaka")
                    .accessibilityHint("Ketuk dua kali untuk menyimpan materi ini ke pustaka")
                }
            }
        }
        .onAppear {
            viewModel.checkSavedStatus()
        }
    }
}

#Preview {
    let repository = MathMaterialRepository(
        modelContext: ModelContext(
            try! ModelContainer(for: DatabaseSchema.schema)
        )
    )
    let sampleMaterial = MathMaterialModel(
        title: "Persamaan Linear Satu Variabel",
        category: "Aljabar",
        content: "Contoh isi materi pembelajaran dari guru."
    )
    return NavigationStack {
        MaterialDetailView(
            viewModel: MaterialDetailViewModel(
                material: sampleMaterial,
                mathMaterialRepository: repository
            )
        )
    }
}
