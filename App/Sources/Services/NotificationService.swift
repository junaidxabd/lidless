import AppKit
import Foundation
import UserNotifications

/// State-clarity notifications: every arm, disarm, and cutoff posts one, so
/// the machine's sleep behavior never changes silently.
@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private var authorizationRequested = false
    /// True in `--render-screenshots` and unit-ish contexts where the
    /// notification center is unavailable or undesirable.
    var suppressed = false

    func activate() {
        guard !suppressed else { return }
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorizationIfNeeded() async {
        guard !suppressed, !authorizationRequested else { return }
        authorizationRequested = true
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    func post(title: String, body: String, sound: Bool = false) {
        guard !suppressed else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if sound { content.sound = .default }
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Audible cue independent of Focus/notification settings — the "your
    /// Mac is about to sleep" chime plays through closed-lid speakers.
    func playCutoffChime() {
        guard !suppressed else { return }
        NSSound(named: "Glass")?.play()
    }

    // Show banners even while the app is frontmost.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
