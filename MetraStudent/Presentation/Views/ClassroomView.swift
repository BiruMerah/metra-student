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
    
    private var displayedClassrooms: [DiscoveredClassroom] {
        if let connectedID = viewModel.connectedClassroomID {
            let connectedList = viewModel.discoveredClassrooms.filter { $0.id == connectedID }
            if !connectedList.isEmpty {
                return connectedList
            }
            if let name = viewModel.connectedClassroomName, let teacher = viewModel.connectedTeacherName {
                return [DiscoveredClassroom(id: connectedID, classroomName: name, teacherName: teacher)]
            }
        }
        return viewModel.discoveredClassrooms
    }
    
    private var emptyClassroomsMessage: String {
        if viewModel.isSearching {
            return "Sedang mencari ruang kelas di sekitar..."
        } else if viewModel.statusMessage == "Idle" || viewModel.statusMessage == "Disconnected" {
            return "Belum ada ruang kelas yang ditemukan"
        } else {
            return viewModel.statusMessage
        }
    }
    
    var body: some View {
        List {
            Section {
                if displayedClassrooms.isEmpty {
                    HStack(spacing: 12) {
                        if viewModel.isSearching {
                            ProgressView()
                                .accessibilityHidden(true)
                        }
                        
                        Text(emptyClassroomsMessage)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        viewModel.isSearching
                        ? "Sedang mencari ruang kelas di sekitar. Mohon tunggu."
                        : "Belum ada ruang kelas yang ditemukan."
                    )
                } else {
                    ForEach(displayedClassrooms) { classroom in
                        ClassroomRowView(
                            classroom: classroom,
                            state: viewModel.connectionState(for: classroom),
                            onJoin: { viewModel.joinClassroom(classroom) },
                            onLeave: { viewModel.leaveCurrentClassroom() }
                        )
                    }
                }
            } header: {
                Text(viewModel.isStudentConnected ? "Ruang Kelas Terhubung" : "Daftar Ruang Kelas")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .textCase(nil)
                    .listRowInsets(EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0))
            }
            .headerProminence(.increased)
            
            if viewModel.isStudentConnected {
                Section {
                    if viewModel.receivedMaterials.isEmpty {
                        Text("Belum ada materi pembelajaran yang dibagikan")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                            .accessibilityLabel("Belum ada materi pembelajaran yang dibagikan oleh guru.")
                    } else {
                        ForEach(viewModel.receivedMaterials) { material in
                            Button {
                                viewModel.openMaterialDetail(material)
                            } label: {
                                HStack {
                                    Text(material.title)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Materi: \(material.title)")
                            .accessibilityHint("Ketuk dua kali untuk membuka detail materi pembelajaran")
                        }
                    }
                } header: {
                    Text("Materi Pembelajaran")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .textCase(nil)
                        .listRowInsets(EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0))
                }
                .headerProminence(.increased)
            }
        }
        .navigationTitle("Ruang Kelas")
        .task {
            viewModel.onAppear()
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
    return NavigationStack {
        coordinator.buildClassroom()
            .navigationDestination(for: AppRoutes.self) { route in
                coordinator.buildDestination(for: route)
            }
    }
}
