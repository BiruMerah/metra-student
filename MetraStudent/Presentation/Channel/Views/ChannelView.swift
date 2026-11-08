//
//  ChannelView.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 06/11/26.
//

import SwiftUI

struct ChannelView: View {
    @Bindable var viewModel: ChannelViewModel
    
    @Environment(\.scenePhase) private var scenePhase
    @State private var isShowingJoinSheet: Bool = false
    
    private var isShowingErrorAlert: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
    
    var body: some View {
        List {
            Section {
                DisplayProfileRow(
                    userName: $viewModel.userName,
                    isInitialSyncing: viewModel.isInitialSyncing,
                    isSignedInToiCloud: viewModel.isSignedInToiCloud,
                    accountStatusMessage: viewModel.accountStatusMessage
                )
            }
            
            Section {
                if viewModel.isInitialSyncing {
                    ChannelSyncingView()
                } else if viewModel.channels.isEmpty {
                    ChannelEmptyView()
                } else {
                    ForEach(viewModel.channels) { channel in
                        NavigationLink(value: channel) {
                            ChannelRow(channel: channel, fileCount: viewModel.fileCount(for: channel))
                        }
                        .swipeActions {
                            Button("Keluar", role: .destructive) {
                                viewModel.leaveChannel(channel)
                            }
                        }
                    }
                }
            } header: {
                Text("Daftar Channel Kelas")
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .refreshable {
            await viewModel.reloadAllChannels()
        }
        .navigationTitle("Channel")
        .navigationDestination(for: ClassroomChannelModel.self) { channel in
            ChannelDetailView(channel: channel) {
                viewModel.leaveChannel(channel)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingJoinSheet = true
                } label: {
                    Label("Gabung Channel", systemImage: "plus")
                }
                .disabled(viewModel.isInitialSyncing)
                .accessibilityHint("Pilih untuk bergabung ke channel kelas baru menggunakan kode undangan guru.")
            }
        }
        .sheet(isPresented: $isShowingJoinSheet) {
            JoinChannelSheet(
                isPresented: $isShowingJoinSheet,
                isLoading: viewModel.isLoading
            ) { code in
                await viewModel.joinChannel(code: code) != nil
            }
        }
        .task {
            await viewModel.initialize()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await viewModel.reloadAllChannels()
                }
            }
        }
        .alert("Pemberitahuan", isPresented: isShowingErrorAlert) {
            Button("Tutup") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

// MARK: - Preview
#Preview {
    let coordinator = AppCoordinator.makePreview()
    return NavigationStack {
        coordinator.buildChannel()
            .navigationDestination(for: AppRoutes.self) { route in
                coordinator.buildDestination(for: route)
            }
    }
}
