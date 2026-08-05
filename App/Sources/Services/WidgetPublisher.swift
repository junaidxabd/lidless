import Foundation
import LidlessCore
import WidgetKit

/// Writes the widget's snapshot to the app-group container and asks
/// WidgetKit to reload — throttled, except for state flips which always
/// publish immediately (the widget must never show a stale armed state).
@MainActor
final class WidgetPublisher {
    static let widgetKind = "LidlessStatus"
    private static let throttleInterval: TimeInterval = 60

    private var lastPublished: WidgetSnapshot?
    private var lastPublishTime = Date.distantPast

    @discardableResult
    func publish(_ snapshot: WidgetSnapshot) -> Bool {
        let stateFlip = lastPublished.map {
            $0.armed != snapshot.armed
                || $0.overrideActive != snapshot.overrideActive
                || $0.overrideStateVerified != snapshot.overrideStateVerified
                || $0.sleepPresentation != snapshot.sleepPresentation
                || $0.statusLine != snapshot.statusLine
        } ?? true
        let elapsed = Date().timeIntervalSince(lastPublishTime)
        guard stateFlip || elapsed >= Self.throttleInterval else { return true }

        guard WidgetStore.save(snapshot) else { return false }
        lastPublished = snapshot
        lastPublishTime = Date()
        WidgetCenter.shared.reloadTimelines(ofKind: Self.widgetKind)
        return true
    }
}
