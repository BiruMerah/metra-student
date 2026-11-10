//
//  HomeView.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 09/11/26.
//

import AudioToolbox
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

struct HomeView: View {
    @Bindable var channelViewModel: ChannelViewModel
    @Bindable var documentViewModel: DocumentViewModel
    
    @Environment(\.scenePhase) private var scenePhase
    @State private var searchText = ""
    @State private var isShowingPDFPicker = false
    @State private var isShowingPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    
    private var isConverting: Bool {
        documentViewModel.progress != nil
    }
    
    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var isSearching: Bool {
        !trimmedSearchText.isEmpty
    }
    
    private var matchingDocuments: [MathMaterialModel] {
        let query = trimmedSearchText
        guard !query.isEmpty else { return documentViewModel.savedMaterials }
        return documentViewModel.savedMaterials.filter { material in
            material.title.localizedStandardContains(query)
                || material.category.localizedStandardContains(query)
                || (material.overview?.localizedStandardContains(query) ?? false)
        }
    }
    
    private var isShowingErrorAlert: Binding<Bool> {
        Binding(
            get: { channelViewModel.errorMessage != nil || documentViewModel.errorMessage != nil },
            set: {
                if !$0 {
                    channelViewModel.errorMessage = nil
                    documentViewModel.errorMessage = nil
                }
            }
        )
    }
    
    private var isShowingSuccessAlert: Binding<Bool> {
        Binding(
            get: { documentViewModel.successMessage != nil },
            set: {
                if !$0 {
                    documentViewModel.clearSuccessMessage()
                }
            }
        )
    }
    
    var body: some View {
        List {
            if channelViewModel.channels.isEmpty {
                // MARK: - Not joining any channel state
                Section {
                    VStack(spacing: 10) {
                        if channelViewModel.isInitialSyncing {
                            ChannelSyncingView()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity)
                                .background(
                                    Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                )
                        } else {
                            JoinChannelButton(
                                isDisabled: channelViewModel.isInitialSyncing || isConverting,
                                action: {
                                    channelViewModel.isShowingJoinSheet = true
                                }
                            )
                        }
                        
                        AddDocumentButton(
                            isDisabled: !documentViewModel.canImport || isConverting,
                            onSelectPDF: {
                                isShowingPDFPicker = true
                            },
                            onSelectPhoto: {
                                isShowingPhotoPicker = true
                            }
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .disabled(isConverting)
                .opacity(isConverting ? 0.45 : 1.0)
                .accessibilityHidden(isConverting)
            } else {
                // MARK: - Already join a channel state
                Section {
                    DisplayProfileRow(
                        userName: $channelViewModel.userName,
                        isInitialSyncing: channelViewModel.isInitialSyncing,
                        isSignedInToiCloud: channelViewModel.isSignedInToiCloud,
                        accountStatusMessage: channelViewModel.accountStatusMessage
                    )
                    
                    ForEach(channelViewModel.channels) { channel in
                        ChannelRow(
                            channel: channel,
                            onLeave: {
                                channelViewModel.leaveChannel(channel)
                            }
                        )
                        .swipeActions {
                            if !isConverting {
                                Button("Keluar", role: .destructive) {
                                    channelViewModel.leaveChannel(channel)
                                }
                            }
                        }
                    }
                }
                .disabled(isConverting)
                .opacity(isConverting ? 0.45 : 1.0)
                .accessibilityHidden(isConverting)
                
                Section {
                    AddDocumentButton(
                        isDisabled: !documentViewModel.canImport || isConverting,
                        onSelectPDF: {
                            isShowingPDFPicker = true
                        },
                        onSelectPhoto: {
                            isShowingPhotoPicker = true
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .disabled(isConverting)
                .opacity(isConverting ? 0.45 : 1.0)
                .accessibilityHidden(isConverting)
            }
            
            // MARK: - Document section
            ImportStatusSection(
                unavailableReason: documentViewModel.importUnavailableReason,
                progress: documentViewModel.progress,
                isCancelling: documentViewModel.isCancelling,
                successMessage: nil,
                onCancel: documentViewModel.cancelImport
            )
            
            Section {
                if !documentViewModel.savedMaterials.isEmpty || isSearching {
                    SearchField(text: $searchText)
                }
                
                if matchingDocuments.isEmpty {
                    if isSearching {
                        ContentUnavailableView(
                            "Dokumen tidak ditemukan",
                            systemImage: "magnifyingglass",
                            description: Text("Tidak ada dokumen yang cocok dengan “\(trimmedSearchText)”.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                            Text("Belum Ada Materi")
                                .font(.headline)
                            Text("Materi yang dibagikan guru di channel atau dokumen yang Anda tambahkan akan otomatis tersimpan dan muncul di sini.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .accessibilityElement(children: .combine)
                    }
                } else {
                    ForEach(matchingDocuments) { material in
                        DocumentRow(
                            material: material,
                            isSelected: nil,
                            onTap: {
                                guard !isConverting else { return }
                                channelViewModel.openMaterialDetail(material)
                            },
                            onDelete: {
                                guard !isConverting else { return }
                                _ = documentViewModel.deleteMaterials(ids: [material.id])
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if !isConverting {
                                Button("Hapus", role: .destructive) {
                                    _ = documentViewModel.deleteMaterials(ids: [material.id])
                                }
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Daftar Dokumen")
                    Spacer()
                    if !documentViewModel.savedMaterials.isEmpty {
                        Text(documentCountText)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(documentHeaderAccessibilityLabel)
                .accessibilityAddTraits(.isHeader)
            }
            .disabled(isConverting)
            .opacity(isConverting ? 0.45 : 1.0)
            .accessibilityHidden(isConverting)
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(12)
        .navigationTitle("Metra")
        .task(id: searchText) {
            guard isSearching else { return }
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            announceSearchResult()
        }
        .refreshable {
            guard !isConverting else { return }
            await channelViewModel.reloadAllChannels()
            documentViewModel.reload()
        }
        .sheet(isPresented: $channelViewModel.isShowingJoinSheet) {
            JoinChannelSheet(
                isPresented: $channelViewModel.isShowingJoinSheet,
                isLoading: channelViewModel.isLoading
            ) { code in
                await channelViewModel.joinChannel(code: code) != nil
            }
        }
        .photosPicker(
            isPresented: $isShowingPhotoPicker,
            selection: $selectedPhoto,
            matching: .images,
            preferredItemEncoding: .current
        )
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            selectedPhoto = nil
            documentViewModel.importPhoto {
                try await item.loadTransferable(type: Data.self)
            }
        }
        .fileImporter(
            isPresented: $isShowingPDFPicker,
            allowedContentTypes: [.pdf]
        ) { result in
            switch result {
            case .success(let url):
                documentViewModel.importDocument(from: url)
            case .failure:
                documentViewModel.errorMessage = "PDF belum dapat dibuka. Coba pilih ulang."
            }
        }
        .onAppear {
            documentViewModel.reload()
        }
        .task {
            await channelViewModel.initialize()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await channelViewModel.reloadAllChannels()
                }
            }
        }
        .onChange(of: documentViewModel.successMessage) { _, newMessage in
            guard let newMessage else { return }
            playConversionCompletionSound(message: newMessage)
        }
        .alert("Konversi Selesai", isPresented: isShowingSuccessAlert) {
            Button("Ok") {
                documentViewModel.clearSuccessMessage()
            }
        } message: {
            Text(documentViewModel.successMessage ?? "Dokumen berhasil dikonversi dan disimpan.")
        }
        .alert("Pemberitahuan", isPresented: isShowingErrorAlert) {
            Button("Tutup") {
                channelViewModel.errorMessage = nil
                documentViewModel.errorMessage = nil
            }
        } message: {
            Text(channelViewModel.errorMessage ?? documentViewModel.errorMessage ?? "")
        }
    }
    
    // MARK: - Search Helpers
    private var documentCountText: String {
        let total = documentViewModel.savedMaterials.count
        guard isSearching else { return "\(total) Dokumen" }
        return "\(matchingDocuments.count) dari \(total) Dokumen"
    }
    
    private var documentHeaderAccessibilityLabel: String {
        let total = documentViewModel.savedMaterials.count
        guard total > 0 else { return "Daftar Dokumen, belum ada dokumen" }
        guard isSearching else {
            return "Daftar Dokumen, \(total) dokumen tersimpan"
        }
        return "Daftar Dokumen, \(matchingDocuments.count) hasil pencarian dari \(total) dokumen"
    }
    
    private func announceSearchResult() {
        let count = matchingDocuments.count
        let message = count == 0
            ? "Tidak ada dokumen yang cocok"
            : "\(count) dokumen ditemukan"
        AccessibilityNotification.Announcement(message).post()
    }
    
    // MARK: - Audio & Accessibility Feedback on Completion
    private func playConversionCompletionSound(message: String) {
        AudioServicesPlaySystemSound(1007)
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
        AccessibilityNotification.Announcement("Konversi selesai. \(message)").post()
    }
}

// MARK: - Preview
#Preview {
    let coordinator = AppCoordinator.makePreview(
        savedMaterials: [
            MathMaterialModel(
                title: "Bab 1 - Persamaan Linear Satu Variabel",
                category: "Aljabar",
                content: "Persamaan linear satu variabel."
            ),
            MathMaterialModel(
                title: "Bab 2 - Teorema Pythagoras",
                category: "Geometri",
                content: "Segitiga siku-siku dan sisi miring."
            )
        ]
    )
    return NavigationStack {
        coordinator.buildHome()
            .navigationDestination(for: AppRoutes.self) { route in
                coordinator.buildDestination(for: route)
            }
    }
}
