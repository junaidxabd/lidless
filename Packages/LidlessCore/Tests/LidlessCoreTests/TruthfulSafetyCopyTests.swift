import Foundation
import Testing

@Suite("Truthful safety copy")
struct TruthfulSafetyCopyTests {
    @Test func incompatibleHelperQuitCopyMakesNoBehaviorPromise() throws {
        let delegate = try repositoryFile("App/Sources/LidlessApp.swift")

        #expect(!delegate.contains("cannot make the sleep setting worse"))
        #expect(!delegate.contains(
            "ending the app's connection is a signal a Lidless helper treats as a reason to restore normal sleep"
        ))
        #expect(delegate.contains("Force-quitting ends app-side verification"))
        #expect(delegate.contains(
            "cannot verify how an incompatible helper will respond"
        ))
    }

    @Test func preCutoffCopyPromisesOnlyTheKeepAwakeEnd() throws {
        let app = try repositoryFile("App/Sources/AppState.swift")
        let warnings = try section(
            of: app,
            from: "private func emitPreCutoffWarnings()",
            through: "// MARK: - Schedule automation"
        )

        #expect(!warnings.contains("Sleeping soon"))
        #expect(!warnings.contains("Lidless restores normal sleep"))
        #expect(warnings.contains("Keep-awake ending soon"))
        #expect(warnings.contains("will request normal sleep"))
    }

    @Test func explanatorySurfacesUseRequestAndProofLanguage() throws {
        let schedules = try repositoryFile(
            "App/Sources/UI/Main/SchedulesPane.swift"
        )
        let cutoffs = try repositoryFile(
            "App/Sources/UI/Main/CutoffsPane.swift"
        )
        let renderer = try repositoryFile(
            "App/Sources/Services/ScreenshotRenderer.swift"
        )

        #expect(schedules.contains("requests and verifies normal sleep"))
        #expect(cutoffs.contains("requests normal sleep"))
        #expect(!renderer.contains("Restores normal sleep"))
        #expect(renderer.contains("Requests normal sleep"))
    }

    @Test func currentArchitectureHasNoUnmarkedRootDuplicate() throws {
        let root = try repositoryRoot()
        let architectureFiles = try FileManager.default
            .contentsOfDirectory(atPath: root.path)
            .filter {
                $0.hasPrefix("ARCHITECTURE") && $0.hasSuffix(".md")
            }
            .sorted()

        #expect(architectureFiles == ["ARCHITECTURE.md"])
    }

    private func repositoryFile(_ relativePath: String) throws -> String {
        var directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
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

    private func repositoryRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        let fileManager = FileManager.default
        while directory.path != "/" {
            if fileManager.fileExists(
                atPath: directory.appendingPathComponent("ARCHITECTURE.md").path
            ), fileManager.fileExists(
                atPath: directory.appendingPathComponent("Packages/LidlessCore").path
            ) {
                return directory
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
}
