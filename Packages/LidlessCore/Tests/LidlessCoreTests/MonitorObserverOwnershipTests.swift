import Foundation
import Testing

@Suite("Monitor notification observer ownership")
struct MonitorObserverOwnershipTests {
    private func repositoryFile(_ relativePath: String) throws -> String {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let fileManager = FileManager.default

        while directory.path != "/" {
            let candidate = directory.appendingPathComponent(relativePath)
            if fileManager.fileExists(atPath: candidate.path) {
                return try String(contentsOf: candidate, encoding: .utf8)
            }
            directory.deleteLastPathComponent()
        }

        throw CocoaError(.fileNoSuchFile)
    }

    private func section(
        of source: String,
        from start: String,
        through end: String
    ) throws -> Substring {
        let startRange = try #require(source.range(of: start))
        let endRange = try #require(source.range(
            of: end,
            range: startRange.upperBound..<source.endIndex
        ))
        return source[startRange.lowerBound..<endRange.upperBound]
    }

    private func occurrenceCount(of needle: String, in source: Substring) -> Int {
        source.components(separatedBy: needle).count - 1
    }

    @Test func systemStateNotificationBlocksDoNotRetainTheMonitor() throws {
        let source = try repositoryFile(
            "App/Sources/Monitors/SystemStateMonitor.swift"
        )
        let start = try section(
            of: source,
            from: "func start() {\n        refresh()",
            through: "func stop()"
        )

        #expect(occurrenceCount(
            of: ") { [weak self] _ in",
            in: start
        ) == 2)
        #expect(occurrenceCount(
            of: "Task { @MainActor [weak self] in",
            in: start
        ) == 2)
        #expect(!start.contains(") { _ in"))
    }

    @Test func thermalNotificationBlockDoesNotRetainTheMonitor() throws {
        let source = try repositoryFile(
            "App/Sources/Monitors/ThermalMonitor.swift"
        )
        let start = try section(
            of: source,
            from: "func start() {\n        guard pollTask == nil",
            through: "func stop()"
        )

        #expect(occurrenceCount(
            of: ") { [weak self] _ in",
            in: start
        ) == 1)
        #expect(occurrenceCount(
            of: "Task { @MainActor [weak self] in",
            in: start
        ) == 1)
        #expect(!start.contains(") { _ in"))
    }
}
