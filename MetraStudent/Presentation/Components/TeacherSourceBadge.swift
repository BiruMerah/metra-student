import SwiftUI

/// Displays a "Dari Guru" badge for materials synced from a teacher's iCloud channel.
struct TeacherSourceBadge: View {
    var channelName: String? = nil
    var teacherName: String? = nil
    var showsContext: Bool = false

    private var contextParts: [String] {
        guard showsContext else { return [] }
        return [channelName, teacherName.map { "Guru: \($0)" }]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var contextText: String? {
        contextParts.isEmpty ? nil : contextParts.joined(separator: " • ")
    }

    private var accessibilityText: String {
        (["Dari Guru"] + contextParts).joined(separator: ", ")
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSize.Spacing.small) {
                pill
                contextLabel
            }

            VStack(alignment: .leading, spacing: AppSize.Spacing.tight) {
                pill
                contextLabel
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(IndonesianSpeech.text(accessibilityText))
    }

    private var pill: some View {
        HStack(spacing: 4) {
            Image(systemName: "graduationcap.fill")
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(AppColor.brand)
                .accessibilityHidden(true)
            IndonesianSpeech.text("Dari Guru")
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(AppColor.heading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, AppSize.Spacing.small)
        .padding(.vertical, 3)
        .background(AppColor.brandSubtle, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(AppColor.brand.opacity(0.25), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var contextLabel: some View {
        if let contextText {
            IndonesianSpeech.text(contextText)
                .font(AppTypography.supporting)
                .foregroundStyle(AppColor.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        TeacherSourceBadge()
        TeacherSourceBadge(
            channelName: "Matematika VII-A",
            teacherName: "Bu Sari",
            showsContext: true
        )
    }
    .padding()
}
