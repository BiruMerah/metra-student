//
//  ClassroomView.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 29/10/26.
//

import SwiftUI
import SwiftData

struct ClassroomView: View {
    @Bindable var viewModel: ClassroomViewModel
    
    var body: some View {
        List {
            Section {
                if viewModel.discoveredClassrooms.isEmpty {
                    HStack(spacing: 14) {
                        if viewModel.isSearching {
                            ProgressView()
                                .accessibilityHidden(true)
                        }
                        
                        Text(viewModel.statusMessage)
                            .font(.title3.weight(.semibold))
                    }
                    .padding(.vertical, 12)
                    .accessibilityElement(children: .combine)
                } else {
                    ForEach(viewModel.discoveredClassrooms) { classroom in
                        ClassroomRowView(
                            classroom: classroom,
                            state: viewModel.connectionState(for: classroom),
                            onJoin: { viewModel.joinClassroom(classroom) },
                            onLeave: { viewModel.leaveCurrentClassroom() }
                        )
                    }
                }
            } header: {
                Text("Daftar ruang kelas (\(viewModel.discoveredClassrooms.count))")
            } footer: {
                if !viewModel.discoveredClassrooms.isEmpty {
                    Text(viewModel.statusMessage)
                }
            }
            
            if viewModel.isStudentConnected {
                Section("Materials") {
                    if viewModel.receivedMaterials.isEmpty {
                        Text("No Materials Yet")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(viewModel.receivedMaterials) { material in
                            Text(material.title)
                                .font(.title3.bold())
                                .padding(.vertical, 8)
                        }
                    }
                }
            }
        }
        .navigationTitle("Ruang Kelas")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.startSearching()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .task {
            viewModel.onAppear()
        }
    }
}

private struct ClassroomRowView: View {
    let classroom: DiscoveredClassroom
    let state: ClassroomConnectionState
    let onJoin: () -> Void
    let onLeave: () -> Void
    
    var body: some View {
        Button {
            switch state {
            case .connected:
                onLeave()
            case .notConnected:
                onJoin()
            case .connecting:
                break
            }
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(classroom.classroomName)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                    
                    Text(classroom.teacherName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                switch state {
                case .connected:
                    Text("Leave")
                        .font(.headline)
                        .foregroundStyle(.red)
                    
                case .connecting:
                    Text("Joining...")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                case .notConnected:
                    Text("Join")
                        .font(.headline)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(state == .connecting)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
    }
    
    private var accessibilityText: String {
        switch state {
        case .connected:
            return "Terhubung ke \(classroom.classroomName), \(classroom.teacherName). Ketuk dua kali untuk keluar."
        case .connecting:
            return "Bergabung ke \(classroom.classroomName)"
        case .notConnected:
            return "Gabung ke \(classroom.classroomName), \(classroom.teacherName)"
        }
    }
}

#Preview {
    let coordinator = AppCoordinator(
        networkManager: NetworkManager(), mathMaterialRepository: MathMaterialRepository(
            modelContext: ModelContext(
                try! ModelContainer(for: DatabaseSchema.schema)
            )
        )
    )
    coordinator.buildClassroom()
}
