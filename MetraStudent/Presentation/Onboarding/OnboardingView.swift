import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState(for: .voiceOver) private var focusedHeading: Step?
    @State private var step: Step = .welcome

    private enum Step {
        case welcome, guide
    }

    var body: some View {
        ScrollView {
            Group {
                switch step {
                case .welcome: welcome
                case .guide: guide
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, AppSize.Spacing.large)
        }
        .id(step)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footer
        }
        .background(AppColor.background.ignoresSafeArea())
        .preferredColorScheme(.light)
        .task(id: step) {
            if step == .guide {
                focusedHeading = .guide
            }
        }
    }

    private var welcome: some View {
        VStack(spacing: 0) {
            MetraWordmark()
                .padding(.horizontal, AppSize.Inset.page)

            heading("Belajar matematika,\ndengan caramu.", on: .welcome)
                .padding(.horizontal, AppSize.Inset.page)
                .padding(.top, 20)

            Image(.onboardingSpokenBook)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 440)
                .accessibilityHidden(true)
                .padding(.top, 38)

            intro("Pahami rumus, ikuti materi per bagian, dan tanyakan yang belum jelas dengan suara.")
                .padding(.horizontal, 36)
                .padding(.top, 46)
        }
        .frame(maxWidth: 440)
        .padding(.top, 32)
    }

    private var guide: some View {
        VStack(spacing: 0) {
            heading("Selamat datang\ndi Metra", on: .guide)

            intro("Belajar matematika dengan cara yang lebih mudah diikuti.")
                .padding(.horizontal, 16)
                .padding(.top, 18)

            VStack(alignment: .leading, spacing: 20) {
                ForEach(Self.features, id: \.title) { feature in
                    featureRow(feature)
                }
            }
            .padding(.top, 26)
        }
        .padding(.horizontal, AppSize.Inset.sheet)
        .frame(maxWidth: 440)
        .padding(.top, 46)
    }

    private func heading(_ title: String, on step: Step) -> some View {
        IndonesianSpeech.text(title)
            .font(AppTypography.screenTitle)
            .foregroundStyle(AppColor.heading)
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
            .accessibilityFocused($focusedHeading, equals: step)
    }

    private func intro(_ description: String) -> some View {
        IndonesianSpeech.text(description)
            .font(AppTypography.readingBody)
            .foregroundStyle(AppColor.secondaryText)
            .multilineTextAlignment(.center)
    }

    private func featureRow(_ feature: Feature) -> some View {
        HStack(alignment: .top, spacing: 14) {
            if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName: feature.symbol)
                    .font(.system(size: 24))
                    .foregroundStyle(AppColor.brand)
                    .frame(width: AppSize.largeIconContainer, height: AppSize.largeIconContainer)
                    .background(AppColor.brandSubtle, in: Circle())
                    .padding(.top, 10)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: AppSize.Spacing.tight) {
                IndonesianSpeech.text(feature.title)
                    .font(AppTypography.headline)
                    .foregroundStyle(.primary)
                IndonesianSpeech.text(feature.description)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColor.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 16 : 40) {
            IndonesianSpeech.text(step == .welcome ? "1 dari 2" : "2 dari 2")
                .font(AppTypography.supporting)
                .foregroundStyle(AppColor.brand)

            Button {
                switch step {
                case .welcome: step = .guide
                case .guide: onFinish()
                }
            } label: {
                IndonesianSpeech.text("Lanjutkan")
            }
            .buttonStyle(MetraActionStyle())
        }
        .padding(.horizontal, AppSize.Inset.sheet)
        .frame(maxWidth: 440)
        .frame(maxWidth: .infinity)
        .padding(.top, AppSize.Spacing.medium)
        .padding(.bottom, AppSize.Spacing.tight)
        .background(AppColor.background)
    }

    private struct Feature {
        let symbol: String
        let title: String
        let description: String
    }

    private static let features = [
        Feature(
            symbol: "f.cursive",
            title: "Rumus dengan suara",
            description: "Baca rumus dalam kalimat yang ramah VoiceOver agar kamu bisa memahami maknanya dalam konteks."
        ),
        Feature(
            symbol: "doc.text.fill",
            title: "Belajar per topik",
            description: "Pelajari materi per topik dan baca satu kalimat demi satu kalimat, sesuai ritmemu."
        ),
        Feature(
            symbol: "mic",
            title: "Asisten Metra",
            description: "Ketuk dua kali pada kalimat yang ingin kamu pahami, lalu ajukan pertanyaan dengan suara."
        ),
        Feature(
            symbol: "graduationcap",
            title: "Materi dari guru",
            description: "Masukkan kode undangan dari guru untuk menerima materi kelas."
        )
    ]
}

#Preview {
    OnboardingView(onFinish: {})
}
