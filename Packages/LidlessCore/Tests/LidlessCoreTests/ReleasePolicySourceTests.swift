import Foundation
import Testing

@Suite("Release signing policy source")
struct ReleasePolicySourceTests {
    private struct VerifierResult {
        let status: Int32
        let standardOutput: String
        let standardError: String
    }

    private struct UnsignedFixture {
        let root: URL
        let app: URL
    }

    private func repositoryURL(_ relativePath: String) throws -> URL {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let fileManager = FileManager.default

        while directory.path != "/" {
            let candidate = directory.appendingPathComponent(relativePath)
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            directory.deleteLastPathComponent()
        }

        throw CocoaError(.fileNoSuchFile)
    }

    private func repositoryFile(_ relativePath: String) throws -> String {
        try String(contentsOf: repositoryURL(relativePath), encoding: .utf8)
    }

    private func writePlist(_ value: [String: Any], to destination: URL) throws {
        let data = try PropertyListSerialization.data(
            fromPropertyList: value,
            format: .xml,
            options: 0
        )
        try data.write(to: destination, options: .atomic)
    }

    private func makeUnsignedFixture() throws -> UnsignedFixture {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("lidless-release-policy-\(UUID().uuidString)")
        let app = root.appendingPathComponent("Lidless.app")
        let appMacOS = app.appendingPathComponent("Contents/MacOS")
        let launchDaemons = app.appendingPathComponent("Contents/Library/LaunchDaemons")
        let widgetContents = app
            .appendingPathComponent("Contents/PlugIns/LidlessWidget.appex/Contents")
        let widgetMacOS = widgetContents.appendingPathComponent("MacOS")

        for directory in [appMacOS, launchDaemons, widgetMacOS] {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }

        for destination in [
            appMacOS.appendingPathComponent("Lidless"),
            appMacOS.appendingPathComponent("LidlessHelper"),
            widgetMacOS.appendingPathComponent("LidlessWidget"),
        ] {
            try fileManager.copyItem(
                at: URL(fileURLWithPath: "/bin/ls"),
                to: destination
            )
            try fileManager.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: destination.path
            )
        }

        try writePlist(
            [
                "CFBundleExecutable": "Lidless",
                "CFBundleIdentifier": "com.lidless.app",
                "CFBundlePackageType": "APPL",
                "CFBundleShortVersionString": "1.0",
                "CFBundleVersion": "1",
            ],
            to: app.appendingPathComponent("Contents/Info.plist")
        )
        try writePlist(
            [
                "CFBundleExecutable": "LidlessWidget",
                "CFBundleIdentifier": "com.lidless.app.widget",
                "CFBundlePackageType": "XPC!",
                "CFBundleShortVersionString": "1.0",
                "CFBundleVersion": "1",
            ],
            to: widgetContents.appendingPathComponent("Info.plist")
        )
        try fileManager.copyItem(
            at: repositoryURL("Helper/Resources/com.lidless.helper.plist"),
            to: launchDaemons.appendingPathComponent("com.lidless.helper.plist")
        )

        return UnsignedFixture(root: root, app: app)
    }

    private func runProcess(
        _ executable: String,
        arguments: [String]
    ) throws -> VerifierResult {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = standardOutput
        process.standardError = standardError
        var environment = ProcessInfo.processInfo.environment
        environment.removeValue(forKey: "BASH_ENV")
        process.environment = environment
        try process.run()
        process.waitUntilExit()

        let output = standardOutput.fileHandleForReading.readDataToEndOfFile()
        let diagnostics = standardError.fileHandleForReading.readDataToEndOfFile()
        return VerifierResult(
            status: process.terminationStatus,
            standardOutput: String(decoding: output, as: UTF8.self),
            standardError: String(decoding: diagnostics, as: UTF8.self)
        )
    }

    private func runVerifier(on app: URL) throws -> VerifierResult {
        try runProcess(
            "/bin/bash",
            arguments: [
                repositoryURL("Scripts/verify_release_bundle.sh").path,
                app.path,
            ]
        )
    }

    @Test func releaseVerifierPinsEveryRuntimeCodeObject() throws {
        let source = try repositoryFile("Scripts/verify_release_bundle.sh")

        for required in [
            "Contents/MacOS/LidlessHelper",
            "Contents/PlugIns/LidlessWidget.appex",
            "com.lidless.app",
            "com.lidless.helper",
            "com.lidless.app.widget",
            "TeamIdentifier",
            "configured signing team is missing, duplicated, or malformed",
            "certificate leaf[subject.OU]",
            "1.2.840.113635.100.6.2.6",
            "1.2.840.113635.100.6.1.13",
            "--strict=all",
            "--all-architectures",
            "--deep",
            "runtime",
            "App/Resources/Lidless.entitlements",
            "Widget/Resources/LidlessWidget.entitlements",
            "embedded.provisionprofile",
            "profiles validate -type provisioning",
            "security cms -D",
            "DeveloperCertificates",
            "ProvisionsAllDevices",
            "ProvisionedDevices",
            "get-task-allow",
            "signing leaf certificate is not authorized by its profile",
            "verify_no_entitlements helper",
            "provisioning profile is expired",
            "app executable name",
            "widget executable name",
            "unexpected symbolic link",
            "missing or unexpected Mach-O code",
            "unexpected executable non-Mach-O file",
            "is not an executable Mach-O file",
            "executable has no architecture",
            "architectures do not match app architectures",
            "/usr/bin/file -E -b",
            "has_owner_executable_mode",
            "has_any_executable_mode",
        ] {
            #expect(source.contains(required))
        }

        let validator = try #require(
            source.range(of: "/usr/bin/profiles validate -type provisioning")
        )
        let decoder = try #require(source.range(of: "/usr/bin/security cms -D"))
        #expect(validator.lowerBound < decoder.lowerBound)
    }

    @Test func releaseVerifierChecksEmbeddedLaunchdIdentity() throws {
        let source = try repositoryFile("Scripts/verify_release_bundle.sh")

        for required in [
            "Contents/Library/LaunchDaemons/com.lidless.helper.plist",
            "AssociatedBundleIdentifiers",
            "BundleProgram",
            "KeepAlive.PathState",
            "MachServices",
        ] {
            #expect(source.contains(required))
        }
    }

    @Test func finalChecksumFollowsStaplerValidation() throws {
        let source = try repositoryFile("Scripts/release.sh")
        let staple = try #require(source.range(of: "xcrun stapler validate \"$APP\""))
        let policy = try #require(source.range(of: "spctl --assess --type execute"))
        let verifier = try #require(
            source.range(of: "Scripts/verify_release_bundle.sh \"$APP\"", range: policy.upperBound..<source.endIndex)
        )
        let distribution = try #require(
            source.range(of: "/usr/bin/syspolicy_check distribution", range: verifier.upperBound..<source.endIndex)
        )
        let artifactVersion = try #require(
            source.range(of: "'Print CFBundleShortVersionString' \"$APP/Contents/Info.plist\"", range: distribution.upperBound..<source.endIndex)
        )
        let finalZip = try #require(
            source.range(of: "/usr/bin/ditto -c -k --keepParent \"$APP\" \"$FINAL_ZIP\"")
        )
        let checksum = try #require(source.range(of: "SHA=$(/usr/bin/shasum -a 256"))

        #expect(staple.lowerBound < policy.lowerBound)
        #expect(policy.lowerBound < verifier.lowerBound)
        #expect(verifier.lowerBound < distribution.lowerBound)
        #expect(distribution.lowerBound < artifactVersion.lowerBound)
        #expect(artifactVersion.lowerBound < finalZip.lowerBound)
        #expect(finalZip.lowerBound < checksum.lowerBound)

        let prepareVerifier = try #require(
            source.range(of: "Scripts/verify_release_bundle.sh \"$APP\"")
        )
        let notaryPolicy = try #require(
            source.range(of: "/usr/bin/syspolicy_check notary-submission")
        )
        #expect(prepareVerifier.lowerBound < notaryPolicy.lowerBound)
    }

    @Test func generatedAndSourceSigningSettingsStayAligned() throws {
        let specification = try repositoryFile("project.yml")
        let project = try repositoryFile("Lidless.xcodeproj/project.pbxproj")
        let teamLines = specification.split(separator: "\n").compactMap { line -> String? in
            let fields = line.split(separator: ":", maxSplits: 1)
            guard fields.count == 2,
                  fields[0].trimmingCharacters(in: .whitespaces) == "DEVELOPMENT_TEAM" else {
                return nil
            }
            return fields[1].trimmingCharacters(in: .whitespaces)
        }
        let team = try #require(teamLines.count == 1 ? teamLines[0] : nil)

        #expect(specification.contains("CODE_SIGN_STYLE: Automatic"))
        #expect(team.count == 10)
        #expect(team.allSatisfy { $0.isUppercase || $0.isNumber })
        #expect(specification.contains("CODE_SIGN_ENTITLEMENTS: App/Resources/Lidless.entitlements"))
        #expect(specification.contains("CODE_SIGN_ENTITLEMENTS: Widget/Resources/LidlessWidget.entitlements"))
        #expect(specification.contains("OTHER_CODE_SIGN_FLAGS: --identifier com.lidless.helper"))
        #expect(!specification.contains("CODE_SIGN_IDENTITY: \"-\""))

        #expect(project.contains("DEVELOPMENT_TEAM = \(team);"))
        #expect(project.contains("CODE_SIGN_ENTITLEMENTS = App/Resources/Lidless.entitlements;"))
        #expect(project.contains("CODE_SIGN_ENTITLEMENTS = Widget/Resources/LidlessWidget.entitlements;"))
        #expect(project.contains("OTHER_CODE_SIGN_FLAGS = \"--identifier com.lidless.helper\";"))
        #expect(!project.contains("CODE_SIGN_IDENTITY = \"-\";"))
    }

    @Test func continuousIntegrationBuildIsExplicitlyUnsigned() throws {
        let workflow = try repositoryFile(".github/workflows/ci.yml")

        #expect(workflow.contains("CODE_SIGNING_ALLOWED=NO build"))
        #expect(!workflow.contains("codesign --verify"))
    }

    @Test func unsignedFixtureReachesAndFailsIdentityPolicy() throws {
        let fixture = try makeUnsignedFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let result = try runVerifier(on: fixture.app)

        #expect(result.status != 0)
        #expect(result.standardError.contains("app architecture"))
        #expect(!result.standardError.contains("missing or unexpected Mach-O code"))
    }

    @Test func unexpectedMachOIsRejectedBeforeSignatureInspection() throws {
        let fixture = try makeUnsignedFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let unexpected = fixture.app
            .appendingPathComponent("Contents/MacOS/UnexpectedExecutable")
        try FileManager.default.copyItem(
            at: URL(fileURLWithPath: "/bin/ls"),
            to: unexpected
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: unexpected.path
        )

        let result = try runVerifier(on: fixture.app)

        #expect(result.status != 0)
        #expect(result.standardError.contains("missing or unexpected Mach-O code"))
        #expect(!result.standardError.contains("app architecture"))
    }

    @Test func symbolicLinkIsRejectedBeforeCodeInspection() throws {
        let fixture = try makeUnsignedFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let resources = fixture.app.appendingPathComponent("Contents/Resources")
        try FileManager.default.createDirectory(
            at: resources,
            withIntermediateDirectories: true
        )
        try FileManager.default.createSymbolicLink(
            at: resources.appendingPathComponent("unexpected-link"),
            withDestinationURL: URL(fileURLWithPath: "/tmp")
        )

        let result = try runVerifier(on: fixture.app)

        #expect(result.status != 0)
        #expect(result.standardError.contains("unexpected symbolic link"))
        #expect(!result.standardError.contains("app architecture"))
    }

    @Test func thinNestedExecutableIsRejectedBeforeIdentityInspection() throws {
        let fixture = try makeUnsignedFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let appExecutable = fixture.app.appendingPathComponent("Contents/MacOS/Lidless")
        let helper = fixture.app.appendingPathComponent("Contents/MacOS/LidlessHelper")
        let architectures = try runProcess(
            "/usr/bin/lipo",
            arguments: ["-archs", appExecutable.path]
        )
        #expect(architectures.status == 0)
        let architecture = try #require(
            architectures.standardOutput.split(whereSeparator: \.isWhitespace).first
        )
        let thinHelper = fixture.root.appendingPathComponent("LidlessHelper.thin")
        let thinning = try runProcess(
            "/usr/bin/lipo",
            arguments: [
                "-thin", String(architecture),
                helper.path,
                "-output", thinHelper.path,
            ]
        )
        #expect(thinning.status == 0)
        try FileManager.default.removeItem(at: helper)
        try FileManager.default.moveItem(at: thinHelper, to: helper)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: helper.path
        )

        let result = try runVerifier(on: fixture.app)

        #expect(result.status != 0)
        #expect(result.standardError.contains("helper architectures do not match app architectures"))
        #expect(!result.standardError.contains("app architecture "))
    }

    @Test func unreadableResourceFailsClosedBeforeIdentityInspection() throws {
        let fixture = try makeUnsignedFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let resources = fixture.app.appendingPathComponent("Contents/Resources")
        try FileManager.default.createDirectory(
            at: resources,
            withIntermediateDirectories: true
        )
        let unreadable = resources.appendingPathComponent("unreadable-resource")
        try Data("unreadable\n".utf8).write(to: unreadable)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o000],
            ofItemAtPath: unreadable.path
        )

        let result = try runVerifier(on: fixture.app)

        #expect(result.status != 0)
        #expect(result.standardError.contains("could not inspect bundle file"))
        #expect(!result.standardError.contains("app architecture"))
    }

    @Test func specialExecutableModeFailsBeforeIdentityInspection() throws {
        let fixture = try makeUnsignedFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let appExecutable = fixture.app.appendingPathComponent("Contents/MacOS/Lidless")
        try FileManager.default.setAttributes(
            // This managed filesystem strips set-id bits from unprivileged
            // files, so use the retained sticky bit to exercise the same
            // forbidden 07000 mode class.
            [.posixPermissions: 0o1755],
            ofItemAtPath: appExecutable.path
        )

        let result = try runVerifier(on: fixture.app)

        #expect(result.status != 0)
        #expect(result.standardError.contains("special file mode is forbidden"))
        #expect(!result.standardError.contains("app architecture"))
    }

    @Test func expectedExecutableWithoutOwnerExecuteFailsBeforeIdentityInspection() throws {
        for permissions in [0o401, 0o410] {
            let fixture = try makeUnsignedFixture()
            defer { try? FileManager.default.removeItem(at: fixture.root) }
            let appExecutable = fixture.app.appendingPathComponent("Contents/MacOS/Lidless")
            try FileManager.default.setAttributes(
                // Keep owner-read so bundle inspection can proceed, while
                // exercising both other-only and group-only execute bits.
                [.posixPermissions: permissions],
                ofItemAtPath: appExecutable.path
            )

            let result = try runVerifier(on: fixture.app)

            #expect(result.status != 0)
            #expect(result.standardError.contains("app executable is missing or not owner-executable"))
            #expect(!result.standardError.contains("app architecture"))
        }
    }

    @Test func executableTextResourceFailsBeforeIdentityInspection() throws {
        let fixture = try makeUnsignedFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let resources = fixture.app.appendingPathComponent("Contents/Resources")
        try FileManager.default.createDirectory(
            at: resources,
            withIntermediateDirectories: true
        )
        let script = resources.appendingPathComponent("unexpected-script")
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: script)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: script.path
        )

        let result = try runVerifier(on: fixture.app)

        #expect(result.status != 0)
        #expect(result.standardError.contains("unexpected executable non-Mach-O file"))
        #expect(!result.standardError.contains("app architecture"))
    }
}
