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
    @Environment(\.accessibilityVoiceOverEnabled) private var isVoiceOverEnabled
    @AccessibilityFocusState(for: .voiceOver) private var isImportProgressFocused: Bool
    @State private var searchText = ""
    @State private var isShowingPDFPicker = false
    @State private var isShowingPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    #if os(iOS)
    @State private var isShowingCamera = false
    @State private var capturedCameraPhoto: Data?
    #endif
    
    private var isConverting: Bool {
        documentViewModel.progress != nil
    }

    private var shouldFocusImportProgress: Bool {
        isVoiceOverEnabled && isConverting && scenePhase == .active && !isShowingPDFPicker && !isShowingPhotoPicker
    }

    private var cameraAction: (() -> Void)? {
        #if os(iOS)
        { isShowingCamera = true }
        #else
        nil
        #endif
    }

    private var addDocumentButton: some View {
        AddDocumentButton(
            isDisabled: !documentViewModel.canImport || isConverting,
            onSelectPDF: { isShowingPDFPicker = true },
            onSelectPhoto: { isShowingPhotoPicker = true },
            onTakePhoto: cameraAction
        )
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
            get: {
                !channelViewModel.isShowingJoinSheet && (channelViewModel.errorMessage != nil || documentViewModel.errorMessage != nil)
            },
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
            get: { documentViewModel.completedImport != nil },
            set: {
                if !$0 {
                    documentViewModel.dismissImportSuccess()
                }
            }
        )
    }
    
    private var homeList: some View {
        List {
            if channelViewModel.channels.isEmpty {
                // MARK: - Not joining any channel state
                Section {
                    VStack(spacing: AppSize.Spacing.actions) {
                        if channelViewModel.isInitialSyncing {
                            ChannelSyncingView()
                                .padding(.horizontal, AppSize.Spacing.large)
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
                        
                        addDocumentButton
                    }
                    .listRowInsets(EdgeInsets(
                        top: AppSize.Spacing.tight,
                        leading: 0,
                        bottom: AppSize.Spacing.tight,
                        trailing: 0
                    ))
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
                                Button(indonesian: "Keluar", role: .destructive) {
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
                    addDocumentButton
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
                onCancel: documentViewModel.cancelImport,
                progressFocus: $isImportProgressFocused
            )
            
            Section {
                if !documentViewModel.savedMaterials.isEmpty || isSearching {
                    SearchField(text: $searchText)
                }
                
                if matchingDocuments.isEmpty {
                    if isSearching {
                        ContentUnavailableView {
                            Label {
                                IndonesianSpeech.text("Dokumen tidak ditemukan")
                                    .font(AppTypography.headline)
                            } icon: {
                                Image(systemName: "magnifyingglass")
                                    .accessibilityHidden(true)
                            }
                        } description: {
                            IndonesianSpeech.text("Tidak ada dokumen yang cocok dengan “\(trimmedSearchText)”.")
                                .font(AppTypography.supporting)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSize.Spacing.small)
                        .accessibilityElement(children: .combine)
                    } else {
                        VStack(spacing: AppSize.Spacing.small) {
                            Image(systemName: "doc.text")
                                .font(.largeTitle)
                                .foregroundStyle(AppColor.brand)
                                .accessibilityHidden(true)
                            IndonesianSpeech.text("Belum Ada Materi")
                                .font(AppTypography.headline)
                                .foregroundStyle(AppColor.heading)
                            IndonesianSpeech.text("Materi dari guru dan dokumen yang kamu tambahkan akan muncul di sini.")
                                .font(AppTypography.supporting)
                                .foregroundStyle(AppColor.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSize.Spacing.large)
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
                                Button(indonesian: "Hapus", role: .destructive) {
                                    _ = documentViewModel.deleteMaterials(ids: [material.id])
                                }
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    IndonesianSpeech.text("Daftar Dokumen")
                        .font(AppTypography.supportingEmphasis)
                        .foregroundStyle(AppColor.heading)
                    Spacer()
                    if !documentViewModel.savedMaterials.isEmpty {
                        IndonesianSpeech.text(documentCountText)
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .textCase(nil)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(IndonesianSpeech.text(documentHeaderAccessibilityLabel))
                .accessibilityAddTraits(.isHeader)
            }
            .disabled(isConverting)
            .opacity(isConverting ? 0.45 : 1.0)
            .accessibilityHidden(isConverting)
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(AppSize.Spacing.medium)
        .contentMargins(.horizontal, AppSize.Inset.page, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background(AppColor.background.ignoresSafeArea())
    }

    var body: some View {
        ScrollViewReader { scroll in
            homeList
                .task(id: shouldFocusImportProgress) {
                    guard shouldFocusImportProgress else { return }
                    do {
                        // Let the picker dismiss, then bring the status row into view.
                        try await Task.sleep(for: .milliseconds(300))
                        scroll.scrollTo(ImportStatusSection.progressID, anchor: .center)
                        try await Task.sleep(for: .milliseconds(150))
                    } catch { return }
                    guard shouldFocusImportProgress, !Task.isCancelled else { return }
                    isImportProgressFocused = true
                }
        }
        .navigationTitle(IndonesianSpeech.text("Metra"))
        .task(id: searchText) {
            guard isSearching else { return }
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled, !isConverting else { return }
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
                errorMessage: $channelViewModel.errorMessage,
                isLoading: channelViewModel.isLoading
            ) { code in
                await channelViewModel.joinChannel(code: code) != nil
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $isShowingCamera, onDismiss: importCapturedPhoto) {
            DocumentCameraView { capturedCameraPhoto = $0 }
        }
        #endif
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
        .refreshable {
            await channelViewModel.reloadAllChannels()
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
        .onChange(of: documentViewModel.completedImport?.id) {
            guard let material = documentViewModel.completedImport else { return }
            playConversionCompletionSound(message: importSuccessMessage(for: material))
        }
        .alert(
            IndonesianSpeech.text("Konversi Selesai"),
            isPresented: isShowingSuccessAlert,
            presenting: documentViewModel.completedImport
        ) { material in
            Button(indonesian: "Buka Materi") {
                documentViewModel.open(material)
            }
        } message: { material in
            IndonesianSpeech.text(importSuccessMessage(for: material))
        }
        .alert(IndonesianSpeech.text("Pemberitahuan"), isPresented: isShowingErrorAlert) {
            Button(indonesian: "Tutup") {
                channelViewModel.errorMessage = nil
                documentViewModel.errorMessage = nil
            }
        } message: {
            IndonesianSpeech.text(channelViewModel.errorMessage ?? documentViewModel.errorMessage ?? "")
        }
    }

    #if os(iOS)
    private func importCapturedPhoto() {
        guard let data = capturedCameraPhoto else { return }
        capturedCameraPhoto = nil
        documentViewModel.importCameraPhoto(data)
    }
    #endif
    
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
        IndonesianSpeech.announce(message)
    }
    
    // MARK: - Audio & Accessibility Feedback on Completion
    private func importSuccessMessage(for material: MathMaterialModel) -> String {
        "“\(material.title)” sudah tersimpan."
    }

    private func playConversionCompletionSound(message: String) {
        AudioServicesPlaySystemSound(1007)
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
        IndonesianSpeech.announce("Konversi selesai. \(message)")
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
