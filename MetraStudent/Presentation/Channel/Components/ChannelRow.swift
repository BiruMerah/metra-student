//
//  ChannelRow.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 08/11/26.
//

import SwiftUI

struct ChannelRow: View {
    let channel: ClassroomChannelModel
    let fileCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "folder.fill.badge.person.crop")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(channel.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    
                    Text("Guru: \(channel.createdBy)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 8)
                
                Text(channel.code)
                    .font(.caption.monospaced().bold())
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.14), in: Capsule())
                    .foregroundStyle(Color.accentColor)
            }
            
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    quotaPill
                    membersPill
                    filesPill
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    quotaPill
                    HStack(spacing: 6) {
                        membersPill
                        filesPill
                    }
                }
            }
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Channel \(channel.name), Kode undangan \(channel.code). Guru: \(channel.createdBy). \(channel.members.count) anggota, \(fileCount) materi.")
    }
    
    private var quotaPill: some View {
        MetadataPill(
            icon: "icloud.fill",
            text: "Kuota: \(channel.createdBy)",
            tint: .blue
        )
    }
    
    private var membersPill: some View {
        MetadataPill(
            icon: "person.2.fill",
            text: "\(channel.members.count) Anggota",
            tint: .secondary
        )
    }
    
    private var filesPill: some View {
        MetadataPill(
            icon: "doc.text.fill",
            text: "\(fileCount) Materi",
            tint: .indigo
        )
    }
}
