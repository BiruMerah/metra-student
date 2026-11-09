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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isShowingPDFPicker = false
    @State private var isShowingPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    
    private var isConverting: Bool {
        documentViewModel.progress != nil
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
                            joinChannelButton
                        }
                        
                        addDocumentButton
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .disabled(isConverting)
                .opacity(isConverting ? 0.45 : 1.0)
                .accessibilityHidden(isConverting)
            } else {
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
                    addDocumentButton
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .disabled(isConverting)
                .opacity(isConverting ? 0.45 : 1.0)
                .accessibilityHidden(isConverting)
            }
            
            ImportStatusSection(
                unavailableReason: documentViewModel.importUnavailableReason,
                progress: documentViewModel.progress,
                isCancelling: documentViewModel.isCancelling,
                successMessage: nil,
                onCancel: documentViewModel.cancelImport
            )
            
            Section {
                if documentViewModel.savedMaterials.isEmpty {
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
                } else {
                    ForEach(documentViewModel.savedMaterials) { material in
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
                        Text("\(documentViewModel.savedMaterials.count) Dokumen")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    documentViewModel.savedMaterials.isEmpty
                        ? "Daftar Dokumen, belum ada dokumen"
                        : "Daftar Dokumen, \(documentViewModel.savedMaterials.count) dokumen tersimpan"
                )
                .accessibilityAddTraits(.isHeader)
            }
            .disabled(isConverting)
            .opacity(isConverting ? 0.45 : 1.0)
            .accessibilityHidden(isConverting)
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(12)
        .refreshable {
            guard !isConverting else { return }
            await channelViewModel.reloadAllChannels()
            documentViewModel.reload()
        }
        .navigationTitle("Metra")
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
    
    // MARK: - Audio & Accessibility Feedback on Completion
    private func playConversionCompletionSound(message: String) {
        AudioServicesPlaySystemSound(1007)
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
        AccessibilityNotification.Announcement("Konversi selesai. \(message)").post()
    }
    
    // MARK: - Gabung Channel Button
    private var joinChannelButton: some View {
        let isLargeText = dynamicTypeSize.isAccessibilitySize
        return Button {
            channelViewModel.isShowingJoinSheet = true
        } label: {
            HStack(spacing: 12) {
                if !isLargeText {
                    IconTile("person.2.badge.plus", tint: .accentColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gabung Channel")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Masukkan kode undangan dari guru")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer(minLength: 8)
                
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(channelViewModel.isInitialSyncing || isConverting)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Gabung Channel Kelas")
        .accessibilityValue("Masukkan kode undangan dari guru")
        .accessibilityHint("Ketuk dua kali untuk membuka formulir kode channel")
        .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - Tambah Dokumen Button
    private var addDocumentButton: some View {
        Menu {
            Button {
                isShowingPDFPicker = true
            } label: {
                Label("Pilih Berkas PDF", systemImage: "doc")
            }
            
            Button {
                isShowingPhotoPicker = true
            } label: {
                Label("Pilih Foto dari Galeri", systemImage: "photo")
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "doc.badge.plus")
                    .font(.title3.weight(.semibold))
                Text("Tambah Dokumen")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .background(
                Color.accentColor,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .foregroundStyle(.white)
        }
        .disabled(!documentViewModel.canImport || isConverting)
        .accessibilityLabel("Tambah Dokumen")
        .accessibilityHint("Pilih foto atau berkas PDF untuk dikonversi menjadi materi matematika bersuara")
    }
}

// MARK: - Preview
#Preview {
    let coordinator = AppCoordinator.makePreview()
    return NavigationStack {
        coordinator.buildHome()
            .navigationDestination(for: AppRoutes.self) { route in
                coordinator.buildDestination(for: route)
            }
    }
}
