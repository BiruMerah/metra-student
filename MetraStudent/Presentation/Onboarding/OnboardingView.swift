import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var isVoiceOverEnabled
    @AccessibilityFocusState(for: .voiceOver) private var focusedHeading: Step?

    @State private var step: Step = .welcome
    @State private var hasNavigatedStep = false
    @State private var hasAnnouncedWelcome = false
    @State private var hasAnnouncedWelcomeWithVoiceOver = false

    private enum Step: Equatable {
        case welcome, guide

        var pageNumber: Int {
            switch self {
            case .welcome: 1
            case .guide: 2
            }
        }

        var pageProgressText: String {
            "Halaman \(pageNumber) dari 2"
        }

        var primaryButtonTitle: String {
            switch self {
            case .welcome: "Lanjutkan"
            case .guide: "Mulai Belajar"
            }
        }

        var primaryButtonSymbol: String {
            switch self {
            case .welcome: "arrow.right"
            case .guide: "checkmark"
            }
        }

        var primaryButtonHint: String {
            switch self {
            case .welcome: "Buka halaman 2 untuk mengenal fitur Metra untuk Siswa."
            case .guide: "Selesaikan pengenalan dan masuk ke beranda aplikasi."
            }
        }
    }

    private static let scrollTopID = "onboarding-scroll-top"
    private static let welcomeAnnouncement = "Selamat datang di Metra Siswa"

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: 0)
                            .id(Self.scrollTopID)
                            .accessibilityHidden(true)

                        Group {
                            switch step {
                            case .welcome: welcome
                            case .guide: guide
                            }
                        }
                        .id(step)
                        .transition(stepTransition)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, AppSize.Inset.sheet)
                }
                .onChange(of: step) { _, _ in
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                        scrollProxy.scrollTo(Self.scrollTopID, anchor: .top)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .contain)

            footer
                .accessibilityElement(children: .contain)
        }
        .background(backgroundCanvas)
        .sensoryFeedback(.selection, trigger: step)
        .accessibilityAction(.escape) {
            if step == .guide {
                navigate(to: .welcome)
            }
        }
        .task(id: isVoiceOverEnabled) {
            await announceWelcomeIfNeeded()
        }
        .task(id: step) {
            guard hasNavigatedStep else { return }
            do { try await Task.sleep(for: .milliseconds(350)) }
            catch { return }
            guard !Task.isCancelled else { return }
            focusedHeading = step
        }
    }

    // MARK: - Background

    private var backgroundCanvas: some View {
        ZStack(alignment: .top) {
            AppColor.background

            RadialGradient(
                colors: [
                    AppColor.brand.opacity(colorScheme == .dark ? 0.14 : 0.08),
                    .clear
                ],
                center: .top,
                startRadius: 20,
                endRadius: 260
            )
            .frame(height: 300)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var stepTransition: AnyTransition {
        if reduceMotion {
            return .identity
        }
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 10)),
            removal: .opacity
        )
    }

    // MARK: - Step 1: Welcome

    private var welcome: some View {
        VStack(spacing: 0) {
            brandBadge
                .padding(.horizontal, AppSize.Inset.sheet)
                .padding(.top, AppSize.Spacing.large)

            heading("Belajar matematika,\ndengan caramu.", spokenAs: "Belajar matematika, dengan caramu.", on: .welcome)
                .padding(.horizontal, AppSize.Inset.sheet)
                .padding(.top, AppSize.Inset.page)

            heroIllustration
                .padding(.top, AppSize.Inset.page)

            welcomeIntroCard
                .padding(.horizontal, AppSize.Inset.sheet)
                .padding(.top, AppSize.Inset.sheet)
        }
        .frame(maxWidth: 460)
        .padding(.top, AppSize.Spacing.medium)
    }

    private var brandBadge: some View {
        HStack(spacing: AppSize.Spacing.small) {
            Image(.onboardingMetraMark)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 22)
                .foregroundStyle(AppColor.brand)
                .accessibilityHidden(true)

            IndonesianSpeech.text("Metra untuk Siswa")
                .font(AppTypography.supportingEmphasis)
                .foregroundStyle(AppColor.heading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, AppSize.Spacing.large)
        .padding(.vertical, AppSize.Spacing.small)
        .background(AppColor.brandSubtle, in: Capsule())
        .overlay(capsuleBorder)
        .accessibilityElement(children: .combine)
    }

    private var heroIllustration: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppColor.brand.opacity(colorScheme == .dark ? 0.22 : 0.1),
                            .clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)

            Image(.onboardingSpokenBook)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private var welcomeIntroCard: some View {
        IndonesianSpeech.text(
            "Pahami rumus, navigasi materi per bagian dengan mudah, dan tanyakan yang belum jelas dengan AI Asisten."
        )
        .font(AppTypography.readingBody)
        .foregroundStyle(AppColor.secondaryText)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(AppSize.Inset.assistantCard)
        .frame(maxWidth: .infinity)
        .background(cardSurface, in: RoundedRectangle(cornerRadius: AppSize.Radius.assistantCard, style: .continuous))
        .overlay(cardBorder(cornerRadius: AppSize.Radius.assistantCard))
        .shadow(color: cardShadowColor, radius: 14, x: 0, y: 6)
    }

    // MARK: - Step 2: Guide

    private var guide: some View {
        VStack(spacing: 0) {
            HStack {
                backButton
                Spacer(minLength: 0)
            }
            .padding(.top, AppSize.Spacing.small)

            heading("Kenali fitur Metra untuk Siswa", on: .guide)
                .padding(.top, AppSize.Spacing.large)

            intro("Empat fitur utama untuk membantumu belajar matematika secara mandiri:")
                .padding(.top, AppSize.Spacing.medium)

            VStack(spacing: AppSize.Spacing.medium) {
                ForEach(Array(Self.features.enumerated()), id: \.element.title) { index, feature in
                    featureCard(feature, index: index)
                }
            }
            .padding(.top, AppSize.Inset.sheet)
        }
        .padding(.horizontal, AppSize.Inset.sheet)
        .frame(maxWidth: 460)
        .padding(.top, AppSize.Spacing.small)
    }

    private var backButton: some View {
        Button {
            navigate(to: .welcome)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(AppTypography.supportingEmphasis)
                    .foregroundStyle(AppColor.brand)
                    .accessibilityHidden(true)
                IndonesianSpeech.text("Kembali")
                    .font(AppTypography.supportingEmphasis)
                    .foregroundStyle(AppColor.heading)
            }
            .padding(.horizontal, AppSize.Spacing.large)
            .frame(minHeight: AppSize.Height.tapTarget)
            .background(AppColor.brandSubtle, in: Capsule())
            .overlay(capsuleBorder)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(IndonesianSpeech.text("Kembali"))
        .accessibilityHint(IndonesianSpeech.text("Kembali ke halaman pertama pengenalan."))
    }

    private func heading(_ title: String, spokenAs: String? = nil, on step: Step) -> some View {
        IndonesianSpeech.text(title, spokenAs: spokenAs)
            .font(AppTypography.screenTitle)
            .foregroundStyle(AppColor.heading)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityFocused($focusedHeading, equals: step)
    }

    private func intro(_ description: String) -> some View {
        IndonesianSpeech.text(description)
            .font(AppTypography.readingBody)
            .foregroundStyle(AppColor.secondaryText)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func featureCard(_ feature: Feature, index: Int) -> some View {
        HStack(alignment: .top, spacing: AppSize.Spacing.medium) {
            if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName: feature.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppColor.brand)
                    .frame(width: AppSize.largeIconContainer, height: AppSize.largeIconContainer)
                    .background(
                        AppColor.brandSubtle,
                        in: RoundedRectangle(cornerRadius: AppSize.Radius.callout, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSize.Radius.callout, style: .continuous)
                            .strokeBorder(AppColor.brand.opacity(borderOpacity(base: 0.18)), lineWidth: 1)
                    )
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: AppSize.Spacing.tight) {
                IndonesianSpeech.text(feature.title)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColor.heading)
                    .fixedSize(horizontal: false, vertical: true)

                IndonesianSpeech.text(feature.description)
                    .font(AppTypography.callout.leading(.loose))
                    .foregroundStyle(AppColor.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppSize.Spacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardSurface, in: RoundedRectangle(cornerRadius: AppSize.Radius.cameraPanel, style: .continuous))
        .overlay(cardBorder(cornerRadius: AppSize.Radius.cameraPanel))
        .shadow(color: cardShadowColor, radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(IndonesianSpeech.text("Fitur \(index + 1) dari \(Self.features.count): \(feature.title)"))
        .accessibilityValue(IndonesianSpeech.text(feature.description))
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: dynamicTypeSize.isAccessibilitySize ? AppSize.Spacing.large : AppSize.Inset.page) {
            stepIndicator

            Button(action: handlePrimaryAction) {
                HStack(spacing: AppSize.Spacing.small) {
                    IndonesianSpeech.text(step.primaryButtonTitle)
                        .font(AppTypography.headline)
                    Image(systemName: step.primaryButtonSymbol)
                        .font(AppTypography.headline)
                        .accessibilityHidden(true)
                }
                .foregroundStyle(AppColor.onBrand)
                .padding(.vertical, AppSize.Spacing.medium)
                .padding(.horizontal, AppSize.Inset.page)
                .frame(maxWidth: .infinity, minHeight: AppSize.Height.largeButton)
                .background(
                    AppColor.brandFill,
                    in: RoundedRectangle(cornerRadius: AppSize.Radius.largeButton, style: .continuous)
                )
                .contentShape(RoundedRectangle(cornerRadius: AppSize.Radius.largeButton, style: .continuous))
                .shadow(
                    color: AppColor.brandFill.opacity(colorScheme == .dark ? 0.35 : 0.25),
                    radius: 12,
                    x: 0,
                    y: 6
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(IndonesianSpeech.text(step.primaryButtonTitle))
            .accessibilityHint(IndonesianSpeech.text(step.primaryButtonHint))
        }
        .padding(.horizontal, AppSize.Inset.sheet)
        .padding(.top, AppSize.Spacing.large)
        .padding(.bottom, AppSize.Spacing.medium)
        .frame(maxWidth: 460)
        .frame(maxWidth: .infinity)
    }

    private var stepIndicator: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: AppSize.Spacing.small) {
                    progressDots
                    progressLabel
                }
            } else {
                HStack(spacing: AppSize.Spacing.medium) {
                    progressDots
                    progressLabel
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(IndonesianSpeech.text(step.pageProgressText))
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach([Step.welcome, Step.guide], id: \.pageNumber) { item in
                Capsule()
                    .fill(item == step ? AppColor.brand : AppColor.brand.opacity(0.24))
                    .frame(width: item == step ? 24 : 8, height: 8)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: step)
            }
        }
        .accessibilityHidden(true)
    }

    private var progressLabel: some View {
        IndonesianSpeech.text(step.pageProgressText)
            .font(AppTypography.supportingEmphasis)
            .foregroundStyle(AppColor.brand)
    }

    // MARK: - Surface Styling Helpers

    private var cardSurface: Color {
        Color(.secondarySystemGroupedBackground)
    }

    private var cardShadowColor: Color {
        colorScheme == .dark ? .clear : Color.black.opacity(0.05)
    }

    private var borderWidth: CGFloat {
        colorSchemeContrast == .increased ? 1.5 : 1
    }

    private func borderOpacity(base: Double) -> Double {
        colorSchemeContrast == .increased ? min(base * 2.2, 0.7) : base
    }

    private var capsuleBorder: some View {
        Capsule()
            .strokeBorder(AppColor.brand.opacity(borderOpacity(base: 0.22)), lineWidth: borderWidth)
            .accessibilityHidden(true)
    }

    private func cardBorder(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(AppColor.brand.opacity(borderOpacity(base: 0.16)), lineWidth: borderWidth)
            .accessibilityHidden(true)
    }

    // MARK: - Actions & Announcements

    private func handlePrimaryAction() {
        switch step {
        case .welcome:
            navigate(to: .guide)
        case .guide:
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
            onFinish()
        }
    }

    private func navigate(to nextStep: Step) {
        guard nextStep != step else { return }
        hasNavigatedStep = true
        focusedHeading = nil
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            step = nextStep
        }
    }

    private func announceWelcomeIfNeeded() async {
        guard step == .welcome else { return }
        if isVoiceOverEnabled {
            guard !hasAnnouncedWelcomeWithVoiceOver else { return }
        } else {
            guard !hasAnnouncedWelcome else { return }
        }

        // Wait briefly for initial presentation layout so VoiceOver does not drop the welcome greeting.
        do { try await Task.sleep(for: .milliseconds(350)) }
        catch { return }

        guard !Task.isCancelled, step == .welcome else { return }

        if isVoiceOverEnabled {
            guard !hasAnnouncedWelcomeWithVoiceOver else { return }
            hasAnnouncedWelcomeWithVoiceOver = true
            hasAnnouncedWelcome = true
        } else {
            guard !hasAnnouncedWelcome else { return }
            hasAnnouncedWelcome = true
        }

        IndonesianSpeech.announce(Self.welcomeAnnouncement, priority: .high)
    }

    // MARK: - Feature Model

    private struct Feature {
        let symbol: String
        let title: String
        let description: String
    }

    private static let features = [
        Feature(
            symbol: "function",
            title: "Rumus yang dibacakan",
            description: "Dengarkan rumus dan simbol matematika dalam bentuk kata-kata agar lebih mudah dipahami melalui VoiceOver."
        ),
        Feature(
            symbol: "list.bullet.indent",
            title: "Belajar selangkah demi selangkah",
            description: "Dengarkan materi per topik dan kalimat satu per satu. Kamu bisa belajar dengan kecepatanmu sendiri."
        ),
        Feature(
            symbol: "sparkles",
            title: "Tanya Asisten Metra",
            description: "Ketuk dua kali pada kalimat yang ingin kamu pahami, lalu ajukan pertanyaan dengan suara."
        ),
        Feature(
            symbol: "person.2.wave.2",
            title: "Kelas bersama guru",
            description: "Masukkan kode undangan dari guru untuk bergabung ke kelas dan menerima materi pelajaran."
        )
    ]
}

#Preview("Sambutan") {
    OnboardingView(onFinish: {})
}
