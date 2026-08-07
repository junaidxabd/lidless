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

    private struct FixtureError: LocalizedError {
        let message: String

        var errorDescription: String? { message }
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

    private func repositoryRoot() throws -> URL {
        try repositoryURL("Scripts/verify_release_bundle.sh")
            .deletingLastPathComponent()
            .deletingLastPathComponent()
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
        let root = try repositoryRoot()
            .appendingPathComponent(".build/local-cache/release-policy-fixtures")
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

        let source = root.appendingPathComponent("fixture-main.c")
        let universalExecutable = root.appendingPathComponent("fixture-universal")
        try Data("int main(void) { return 0; }\n".utf8).write(
            to: source,
            options: .atomic
        )
        let compilation = try runProcess(
            "/usr/bin/clang",
            arguments: [
                "-arch", "arm64",
                "-arch", "x86_64",
                source.path,
                "-o", universalExecutable.path,
            ]
        )
        guard compilation.status == 0 else {
            throw FixtureError(
                message: "could not build deterministic universal fixture: "
                    + compilation.standardError
            )
        }
        let architectureInventory = try runProcess(
            "/usr/bin/lipo",
            arguments: ["-archs", universalExecutable.path]
        )
        let architectures = Set(
            architectureInventory.standardOutput.split(whereSeparator: \.isWhitespace)
                .map(String.init)
        )
        guard architectureInventory.status == 0,
              architectures == Set(["arm64", "x86_64"]) else {
            throw FixtureError(
                message: "deterministic fixture has unexpected architectures: "
                    + architectureInventory.standardOutput
                    + architectureInventory.standardError
            )
        }

        for destination in [
            appMacOS.appendingPathComponent("Lidless"),
            appMacOS.appendingPathComponent("LidlessHelper"),
            widgetMacOS.appendingPathComponent("LidlessWidget"),
        ] {
            try fileManager.copyItem(
                at: universalExecutable,
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
        arguments: [String],
        environmentOverrides: [String: String] = [:]
    ) throws -> VerifierResult {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = standardOutput
        process.standardError = standardError
        process.currentDirectoryURL = try repositoryRoot()
        var environment = ProcessInfo.processInfo.environment
        environment.removeValue(forKey: "BASH_ENV")
        for (key, value) in environmentOverrides {
            environment[key] = value
        }
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
            ],
            environmentOverrides: [
                "TMPDIR": app.deletingLastPathComponent().path,
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
            "MachServices",
        ] {
            #expect(source.contains(required))
        }
        for requiredPath in [
            "/var/db/lidless/override-active",
            "/var/db/lidless/mutation-in-flight.json",
            "/var/db/lidless/scheduled-wake-recovery-required.json",
        ] {
            #expect(source.contains(
                "Print :KeepAlive:PathState:\(requiredPath)"
            ))
        }
        #expect(source.contains("launchd recovery path count"))
        #expect(source.contains("/usr/bin/grep -c ' = '"))
        #expect(!source.contains(
            "'{\"/var/db/lidless/override-active\":true}'"
        ))
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

    @Test func continuousIntegrationUsesLeastPrivilegeCheckout() throws {
        let workflow = try repositoryFile(".github/workflows/ci.yml")
        let permissionBlock = "permissions:\n  contents: read"
        let checkout = "- uses: actions/checkout@v4"
        let hardenedCheckout = "      - uses: actions/checkout@v4\n"
            + "        with:\n"
            + "          persist-credentials: false"
        let checkoutCount = workflow.components(separatedBy: checkout).count - 1
        let hardenedCount = workflow.components(separatedBy: hardenedCheckout).count - 1

        #expect(workflow.contains(permissionBlock))
        #expect(!workflow.contains("contents: write"))
        #expect(checkoutCount == 4)
        #expect(hardenedCount == checkoutCount)

        let permissions = try #require(workflow.range(of: permissionBlock))
        let jobs = try #require(workflow.range(of: "jobs:"))
        #expect(permissions.lowerBound < jobs.lowerBound)
    }

    @Test func continuousIntegrationCoversEveryOfflineBuildPolicyGate() throws {
        let workflow = try repositoryFile(".github/workflows/ci.yml")

        for required in [
            "swift test --package-path Packages/LidlessCore",
            "configuration: [Debug, Release]",
            "-configuration \"${{ matrix.configuration }}\"",
            "CODE_SIGNING_ALLOWED=NO build",
            "CODE_SIGNING_ALLOWED=NO analyze",
            "xcodegen generate",
            "git diff --exit-code -- Lidless.xcodeproj",
            "/bin/bash -n Scripts/release.sh",
            "/bin/bash -n Scripts/verify_release_bundle.sh",
        ] {
            #expect(workflow.contains(required))
        }
        #expect(!workflow.contains("swift test --disable-sandbox"))

        let generation = try #require(workflow.range(of: "xcodegen generate"))
        let drift = try #require(workflow.range(
            of: "git diff --exit-code -- Lidless.xcodeproj"
        ))
        #expect(generation.lowerBound < drift.lowerBound)
    }

    @Test func distributionRequiresBothArchitecturesInsteadOfOnlySharedThinCode() throws {
        let verifier = try repositoryFile("Scripts/verify_release_bundle.sh")
        let release = try repositoryFile("Scripts/release.sh")

        for required in [
            "for required_arch in arm64 x86_64",
            "/usr/bin/grep -Fxq \"$required_arch\"",
            "executable is missing required architecture $required_arch",
            "require_distribution_architectures app",
            "require_distribution_architectures helper",
            "require_distribution_architectures widget",
        ] {
            #expect(verifier.contains(required))
        }
        #expect(verifier.contains("architectures do not match app architectures"))
        #expect(release.contains("RELEASE_ARCHITECTURES=\"arm64 x86_64\""))
        #expect(release.contains("ARCHS=\"$RELEASE_ARCHITECTURES\""))
        #expect(release.contains("ONLY_ACTIVE_ARCH=NO"))
    }

    @Test func constrainedWorkspaceTargetKeepsCachesLocalWithoutWeakeningNormalTest() throws {
        let makefile = try repositoryFile("Makefile")

        #expect(makefile.contains(
            "test:\n\tswift test --package-path Packages/LidlessCore"
        ))
        #expect(makefile.contains("test-local:"))
        #expect(makefile.contains("$(CURDIR)/.build/local-cache"))
        #expect(makefile.contains("CLANG_MODULE_CACHE_PATH="))
        #expect(makefile.contains("SWIFTPM_MODULECACHE_OVERRIDE="))
        #expect(makefile.contains("TMPDIR=\"$(LOCAL_TMP)\""))
        #expect(makefile.contains("XDG_CACHE_HOME=\"$(LOCAL_XDG_CACHE)\""))
        #expect(makefile.contains("--cache-path"))
        #expect(makefile.contains("--config-path"))
        #expect(makefile.contains("--security-path"))
        #expect(makefile.contains("--scratch-path"))
        #expect(makefile.contains("--disable-sandbox"))
        #expect(makefile.contains("restricted workspace"))
        #expect(makefile.contains("Normal environments and CI should keep using `make test`"))
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

    @Test func equallyThinExecutablesFailDistributionBeforeIdentityInspection() throws {
        let fixture = try makeUnsignedFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let executables = [
            fixture.app.appendingPathComponent("Contents/MacOS/Lidless"),
            fixture.app.appendingPathComponent("Contents/MacOS/LidlessHelper"),
            fixture.app.appendingPathComponent(
                "Contents/PlugIns/LidlessWidget.appex/Contents/MacOS/LidlessWidget"
            ),
        ]
        let inventory = try runProcess(
            "/usr/bin/lipo",
            arguments: ["-archs", executables[0].path]
        )
        let architectures = inventory.standardOutput.split(whereSeparator: \.isWhitespace)
        let retainedArchitecture = try #require(architectures.first)
        #expect(inventory.status == 0)

        if architectures.count > 1 {
            let thin = fixture.root.appendingPathComponent("equally-thin-executable")
            let thinning = try runProcess(
                "/usr/bin/lipo",
                arguments: [
                    "-thin", String(retainedArchitecture),
                    executables[0].path,
                    "-output", thin.path,
                ]
            )
            #expect(thinning.status == 0)
            for executable in executables {
                try FileManager.default.removeItem(at: executable)
                try FileManager.default.copyItem(at: thin, to: executable)
                try FileManager.default.setAttributes(
                    [.posixPermissions: 0o755],
                    ofItemAtPath: executable.path
                )
            }
        }

        for executable in executables {
            let observed = try runProcess(
                "/usr/bin/lipo",
                arguments: ["-archs", executable.path]
            )
            #expect(observed.status == 0)
            #expect(observed.standardOutput.split(whereSeparator: \.isWhitespace)
                == [retainedArchitecture])
        }

        let result = try runVerifier(on: fixture.app)

        #expect(result.status != 0)
        #expect(result.standardError.contains(
            "app executable is missing required architecture"
        ))
        #expect(!result.standardError.contains(
            "architectures do not match app architectures"
        ))
        #expect(!result.standardError.contains("signing information is unreadable"))
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
