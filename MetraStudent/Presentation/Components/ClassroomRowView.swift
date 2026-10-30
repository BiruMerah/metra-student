//
//  ClassroomRowView.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 30/10/26.
//

import SwiftUI

struct ClassroomRowView: View {
    let classroom: DiscoveredClassroom
    let state: ClassroomConnectionState
    let onJoin: () -> Void
    let onLeave: () -> Void
    
    private var wifiColor: Color {
        switch state {
        case .connected:
            return .green
        case .connecting:
            return .blue.opacity(0.6)
        case .notConnected:
            return .secondary
        }
    }
    
    private var classroomInfoAccessibilityLabel: String {
        switch state {
        case .connected:
            return "Terhubung ke ruang kelas \(classroom.classroomName), guru \(classroom.teacherName)"
        case .connecting:
            return "Sedang bergabung ke ruang kelas \(classroom.classroomName), guru \(classroom.teacherName)"
        case .notConnected:
            return "Ruang kelas \(classroom.classroomName), guru \(classroom.teacherName)"
        }
    }
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "wifi")
                .font(.title2)
                .foregroundStyle(wifiColor)
                .frame(width: 28, alignment: .center)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(classroom.classroomName)
                    .font(.body.weight(.bold))
                    .foregroundStyle(.primary)
                
                Text(classroom.teacherName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(classroomInfoAccessibilityLabel)
            
            Spacer()
            
            switch state {
            case .connected:
                Button(role: .destructive, action: onLeave) {
                    Text("Leave")
                        .font(.subheadline.weight(.semibold))
                        .frame(minWidth: 64)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .buttonBorderShape(.capsule)
                .accessibilityLabel("Keluar dari \(classroom.classroomName)")
                .accessibilityHint("Ketuk dua kali untuk keluar dari ruang kelas ini")
                
            case .connecting:
                Button(action: {}) {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Joining...")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(minWidth: 64)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
                .buttonBorderShape(.capsule)
                .disabled(true)
                .accessibilityLabel("Sedang bergabung ke \(classroom.classroomName)")
                .accessibilityHint("Mohon tunggu proses penghubungan")
                
            case .notConnected:
                Button(action: onJoin) {
                    Text("Join")
                        .font(.subheadline.weight(.semibold))
                        .frame(minWidth: 64)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .buttonBorderShape(.capsule)
                .accessibilityLabel("Gabung ke \(classroom.classroomName)")
                .accessibilityHint("Ketuk dua kali untuk bergabung ke ruang kelas ini")
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview("Not Connected") {
    List {
        ClassroomRowView(
            classroom: .sample,
            state: .notConnected,
            onJoin: {},
            onLeave: {}
        )
    }
}

#Preview("Connecting") {
    List {
        ClassroomRowView(
            classroom: .sampleConnecting,
            state: .connecting,
            onJoin: {},
            onLeave: {}
        )
    }
}

#Preview("Connected") {
    List {
        ClassroomRowView(
            classroom: .sampleConnected,
            state: .connected,
            onJoin: {},
            onLeave: {}
        )
    }
}
