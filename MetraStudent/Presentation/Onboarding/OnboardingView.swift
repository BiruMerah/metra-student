import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState(for: .voiceOver) private var focusedHeading: Step?
    @State private var step: Step = .welcome

    private enum Step {
        case welcome, guide
    }

    private let background = Color(red: 252 / 255, green: 251 / 255, blue: 248 / 255)
    private let navy = Color(red: 20 / 255, green: 38 / 255, blue: 72 / 255)
    private let blue = Color(red: 50 / 255, green: 102 / 255, blue: 212 / 255)
    private let badgeFill = Color(red: 234 / 255, green: 240 / 255, blue: 1)
    private let bodyColor = Color(white: 73 / 255)

    var body: some View {
        ScrollView {
            Group {
                switch step {
                case .welcome: welcome
                case .guide: guide
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)
        }
        .id(step)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footer
        }
        .background(background.ignoresSafeArea())
        .preferredColorScheme(.light)
        .task(id: step) {
            if step == .guide {
                focusedHeading = .guide
            }
        }
    }

    private var welcome: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(.onboardingMetraMark)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 33, height: 31)
                    .accessibilityHidden(true)
                IndonesianSpeech.text("Metra Student")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(navy)
            }
            .frame(minHeight: 40)
            .padding(.horizontal, 20)

            heading("Belajar matematika,\ndengan caramu.", on: .welcome)
                .padding(.horizontal, 20)
                .padding(.top, 20)

            Image(.onboardingSpokenBook)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 440)
                .accessibilityHidden(true)
                .padding(.top, 38)

            intro("Pahami rumus, navigasi materi per bagian dengan mudah, dan tanyakan yang belum jelas dengan Metra Assistant.")
                .padding(.horizontal, 36)
                .padding(.top, 46)
        }
        .frame(maxWidth: 440)
        .padding(.top, 32)
    }

    private var guide: some View {
        VStack(spacing: 0) {
            heading("Selamat datang\ndi Metra", on: .guide)

            intro("Belajar matematika untuk tunanetra")
                .padding(.horizontal, 16)
                .padding(.top, 18)

            VStack(alignment: .leading, spacing: 20) {
                ForEach(Self.features, id: \.title) { feature in
                    featureRow(feature)
                }
            }
            .padding(.top, 26)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 440)
        .padding(.top, 46)
    }

    private func heading(_ title: String, on step: Step) -> some View {
        IndonesianSpeech.text(title)
            .font(.largeTitle.bold())
            .foregroundStyle(navy)
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
            .accessibilityFocused($focusedHeading, equals: step)
    }

    private func intro(_ description: String) -> some View {
        IndonesianSpeech.text(description)
            .font(.body)
            .foregroundStyle(bodyColor)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
    }

    private func featureRow(_ feature: Feature) -> some View {
        HStack(alignment: .top, spacing: 14) {
            if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName: feature.symbol)
                    .font(.system(size: 24))
                    .foregroundStyle(blue)
                    .frame(width: 48, height: 48)
                    .background(badgeFill, in: Circle())
                    .padding(.top, 10)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 4) {
                IndonesianSpeech.text(feature.title)
                    .font(.headline)
                    .foregroundStyle(.black)
                IndonesianSpeech.text(feature.description)
                    .font(.callout)
                    .foregroundStyle(bodyColor)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 16 : 40) {
            IndonesianSpeech.text(step == .welcome ? "1 dari 2" : "2 dari 2")
                .font(.subheadline)
                .foregroundStyle(blue)

            Button {
                switch step {
                case .welcome: step = .guide
                case .guide: onFinish()
                }
            } label: {
                IndonesianSpeech.text("Lanjutkan")
                    .font(.body)
                    .foregroundStyle(.white)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(blue, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 440)
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .background(background)
    }

    private struct Feature {
        let symbol: String
        let title: String
        let description: String
    }

    private static let features = [
        Feature(
            symbol: "f.cursive",
            title: "Matematika lisan",
            description: "Belajar matematika dan rumus yang ramah VoiceOver agar kamu bisa memahami maknanya dalam konteks."
        ),
        Feature(
            symbol: "doc.text.fill",
            title: "Navigasi materi dengan mudah",
            description: "Pelajari materi per topik dan baca satu kalimat demi satu kalimat, sesuai ritmemu."
        ),
        Feature(
            symbol: "mic",
            title: "Metra Assistant",
            description: "Ketuk dua kali pada kalimat materi yang ingin kamu pahami, lalu ajukan pertanyaan dengan suara."
        ),
        Feature(
            symbol: "graduationcap",
            title: "Channel dengan guru",
            description: "Masukkan kode undangan dari guru untuk gabung channel dan menerima materi kelas."
        )
    ]
}

#Preview {
    OnboardingView(onFinish: {})
}
