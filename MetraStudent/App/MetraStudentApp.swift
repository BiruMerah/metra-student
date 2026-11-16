//
//  MetraStudentApp.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 28/10/26.
//

import SwiftUI
import SwiftData

@main
struct MetraStudentApp: App {
    @UIApplicationDelegateAdaptor(StudentCloudShareAppDelegate.self) private var appDelegate
    @AppStorage("hasCompletedStudentOnboarding") private var hasCompletedOnboarding = false
    @State private var coordinator: AppCoordinator
    @State private var invitationInbox = ClassroomInvitationInbox.shared
    @State private var routedInvitationID: String?
    private let modelContainer: ModelContainer
    
    init() {
        // MARK: - Data Layer setup
        let container: ModelContainer
        let storageIsPersistent: Bool
        do {
            let config = ModelConfiguration(
                schema: DatabaseSchema.schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none // Prevent conflict with cloudKit entitlement
            )
            container = try ModelContainer(for: DatabaseSchema.schema, configurations: config)
            storageIsPersistent = true
        } catch {
            print("SwiftData store error: \(error). Falling back to in-memory store.")
            do {
                let fallbackConfig = ModelConfiguration(
                    schema: DatabaseSchema.schema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                )
                container = try ModelContainer(for: DatabaseSchema.schema, configurations: fallbackConfig)
                storageIsPersistent = false
            } catch {
                fatalError("Failed to initialize SwiftData ModelContainer: \(error)")
            }
        }
        self.modelContainer = container
        let mathMaterialRepository = MathMaterialRepository(modelContext: modelContainer.mainContext)
        let notificationManager = NotificationManager()
        
        // MARK: - Presentation Layer setup
        let initialCoordinator = AppCoordinator(
            mathMaterialRepository: mathMaterialRepository,
            notificationManager: notificationManager,
            storageIsPersistent: storageIsPersistent
        )
        _coordinator = State(wrappedValue: initialCoordinator)
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    ContentView(coordinator: coordinator)
                } else {
                    OnboardingView {
                        hasCompletedOnboarding = true
                    }
                }
            }
            .onOpenURL { invitationInbox.receive($0) }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                if let url = activity.webpageURL { invitationInbox.receive(url) }
            }
            .onChange(of: invitationInbox.current, initial: true) { _, _ in routeInvitationIfReady() }
            .onChange(of: hasCompletedOnboarding) { _, _ in routeInvitationIfReady() }
            .alert(IndonesianSpeech.text("Undangan kelas"), isPresented: Binding(
                get: { invitationInbox.errorMessage != nil },
                set: { if !$0 { invitationInbox.errorMessage = nil } })) {
                    Button(indonesian: "Tutup", role: .cancel) { invitationInbox.errorMessage = nil }
                } message: { IndonesianSpeech.text(invitationInbox.errorMessage ?? "") }
        }
        .environment(\.locale, IndonesianSpeech.locale)
    }

    private func routeInvitationIfReady() {
        guard hasCompletedOnboarding else { return }
        guard let link = invitationInbox.current else { routedInvitationID = nil; return }
        guard routedInvitationID != link.id else { return }
        routedInvitationID = link.id
        coordinator.navigate(to: .classroomInvitation(link))
    }
}
