//
//  NotificationManager.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 01/11/26.
//

import Foundation
import OSLog
import SwiftUI
import UIKit
import UserNotifications

@MainActor
final class NotificationManager: NSObject, NotificationProtocol, UNUserNotificationCenterDelegate {
    private let notificationCenter: UNUserNotificationCenter
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MetraStudent",
        category: "MaterialNotifications"
    )
    private var authorizationTask: Task<Void, Never>?

    init(notificationCenter: UNUserNotificationCenter = .current()) {
        self.notificationCenter = notificationCenter
        super.init()
        notificationCenter.delegate = self
    }

    func requestAuthorizationIfNeeded() async {
        if let authorizationTask {
            await authorizationTask.value
            return
        }

        let task = Task {
            let settings = await notificationCenter.notificationSettings()
            guard settings.authorizationStatus == .notDetermined else { return }

            do {
                _ = try await notificationCenter.requestAuthorization(options: [.alert, .sound])
            } catch {
                print("Unable to request notification permission: \(error.localizedDescription)")
            }
        }
        authorizationTask = task
        await task.value
        authorizationTask = nil
    }

    func announceAccessibility(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }

    func notifyNewMaterials(_ materials: [MathMaterialModel], classroomID: String, classroomName: String) {
        guard !materials.isEmpty else { return }

        let message: String
        if materials.count == 1, let material = materials.first {
            message = "Materi \(material.title) telah diterima dari kelas \(classroomName)."
        } else {
            message = "\(materials.count) materi baru telah diterima dari kelas \(classroomName)."
        }

        Task {
            await requestAuthorizationIfNeeded()
            let settings = await notificationCenter.notificationSettings()

            if UIApplication.shared.applicationState == .active {
                AccessibilityNotification.Announcement(message).post()
                Task { await playDoubleHaptic() }
            }

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                break
            default:
                // VoiceOver and foreground haptics still work when permission is denied.
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "Materi Baru"
            content.body = message
            content.sound = .default
            content.threadIdentifier = "classroom.\(classroomID)"

            let request = UNNotificationRequest(
                identifier: "classroom-materials.\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            do {
                try await notificationCenter.add(request)
            } catch {
                print("Unable to deliver material notification: \(error.localizedDescription)")
            }
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Keep foreground feedback to our two explicit pulses; the default
        // notification sound and vibration are reserved for background delivery.
        [.banner, .list]
    }

    private func playDoubleHaptic() async {
        guard UIApplication.shared.applicationState == .active else { return }

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        generator.prepare()

        do { try await Task.sleep(for: .milliseconds(250)) }
        catch { return }

        guard UIApplication.shared.applicationState == .active else { return }
        generator.impactOccurred()
    }
}
