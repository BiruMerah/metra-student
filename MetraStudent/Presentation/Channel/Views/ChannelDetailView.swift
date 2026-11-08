//
//  ChannelDetailView.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 09/11/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ChannelDetailView: View {
    let channel: ClassroomChannelModel
    var onLeave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isCodeCopied = false
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(channel.name)
                            .font(.title3.weight(.bold))
                        Spacer()
                        Button {
                            #if canImport(UIKit)
                            UIPasteboard.general.string = channel.code
                            #endif
                            isCodeCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                isCodeCopied = false
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(channel.code)
                                    .font(.caption.monospaced().bold())
                                Image(systemName: isCodeCopied ? "checkmark" : "doc.on.doc")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Salin kode channel \(channel.code)")
                    }
                    
                    HStack(spacing: 12) {
                        Label("Guru: \(channel.createdBy)", systemImage: "person.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Label("\(channel.members.count) Anggota", systemImage: "person.2.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Informasi Channel")
            }
            
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "folder")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Materi Kelas")
                        .font(.headline)
                    Text("Materi yang dibagikan guru di channel ini akan muncul di sini.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } header: {
                Text("Daftar Materi")
            }
            
            Section {
                Button("Keluar dari Channel", role: .destructive) {
                    onLeave()
                    dismiss()
                }
            }
        }
        .navigationTitle(channel.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
