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

    // Sample topics until the material model provides topic data.
    private let topics = TopicViewModel.sampleTopics

    var body: some View {
        List {
            Section {
                Text(viewModel.material.title)
                    .font(.title.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                    .textSelection(.enabled)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
            }

            Section("Overview") {
                overviewContent
            }

            Section {
                ForEach(Array(topics.enumerated()), id: \.element.id) { index, topic in
                    NavigationLink {
                        TopicView(topics: topics, initialTopicIndex: index)
                    } label: {
                        topicRow(topic, index: index)
                    }
                    .accessibilityLabel("Topik \(index + 1), \(topic.title)")
                    .accessibilityHint("Buka detail topik")
                }
            } header: {
                Text("Topik")
            } footer: {
                Text("Pilih topik untuk melihat detailnya.")
            }

//            Section {
//                LabeledContent("Kategori", value: viewModel.material.category)
//
//                LabeledContent("Tanggal dibuat") {
//                    Text(viewModel.material.createdAt, format: .dateTime.day().month(.abbreviated).year())
//                }
//            } header: {
//                Text("Informasi Materi")
//            } footer: {
//                if viewModel.isSaved {
//                    Text("Materi ini tersimpan di pustaka.")
//                } else if viewModel.hasDuplicateTitle {
//                    Text("Materi dengan judul yang sama sudah ada di pustaka.")
//                }
//            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Detail Materi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.isSaved {
                    Menu {
                        Button(role: .destructive) {
                            viewModel.unsaveMaterial()
                        } label: {
                            Label("Hapus dari Pustaka", systemImage: "bookmark.slash")
                        }
                    } label: {
                        Label("Materi Tersimpan", systemImage: "bookmark.fill")
                    }
                    .accessibilityHint("Buka pilihan materi tersimpan")
                } else {
                    Button {
                        viewModel.saveMaterial()
                    } label: {
                        Label("Simpan ke Pustaka", systemImage: "bookmark")
                    }
                    .disabled(!viewModel.canSave)
                }
            }
        }
        .onAppear {
            viewModel.checkSavedStatus()
        }
        .alert("Terjadi Kesalahan", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            overviewLine("Bab", value: viewModel.overview.chapter)
            overviewLine("Subbab", value: viewModel.overview.subchapter)
            overviewLine("Halaman", value: viewModel.overview.pageNumber.formatted())
        }
        .padding(.vertical, 6)
    }

    private func overviewLine(_ title: String, value: String) -> some View {
        Text("\(title): \(value)")
            .font(.body)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
            .accessibilityLabel("\(title), \(value)")
    }

    @ViewBuilder
    private var overviewCounts: some View {
        countBadge("\(topics.count) Topik", symbol: "list.bullet")
            .accessibilityLabel("\(topics.count) topik pembelajaran")
        countBadge("\(viewModel.overview.questionCount) Soal", symbol: "questionmark.circle")
            .accessibilityLabel("\(viewModel.overview.questionCount) soal latihan")
    }

    private func countBadge(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.06), in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
    }

    private func topicRow(_ topic: MathTopicModel, index: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 52, height: 52)
                .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(topic.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        .alignmentGuide(.listRowSeparatorLeading) { dimensions in
            dimensions[.leading] + 64
        }
    }
}

#Preview {
    let repository = MathMaterialRepository(
        modelContext: ModelContext(
            try! ModelContainer(
                for: DatabaseSchema.schema,
                configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
            )
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
