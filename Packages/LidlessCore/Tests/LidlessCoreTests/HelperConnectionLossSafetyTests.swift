import Foundation
import Testing
@testable import LidlessCore

@Suite("Helper connection loss safety")
struct HelperConnectionLossSafetyTests {
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
        from startMarker: String,
        through endMarker: String
    ) throws -> Substring {
        let start = try #require(source.range(of: startMarker))
        let end = try #require(source.range(
            of: endMarker,
            range: start.upperBound..<source.endIndex
        ))
        return source[start.lowerBound..<end.lowerBound]
    }

    @Test func serverTreatsInterruptionAndInvalidationAsOneTerminalEvent() throws {
        let helper = try repositoryFile("Helper/HelperDaemon.swift")
        let listener = try section(
            of: helper,
            from: "func listener(_ listener: NSXPCListener",
            through: "// MARK: - Per-connection XPC facade"
        )

        #expect(listener.contains("let connectionID = UUID()"))
        #expect(listener.contains("newConnection.interruptionHandler"))
        #expect(listener.contains("newConnection?.invalidate()"))
        #expect(listener.contains("newConnection.invalidationHandler"))
        #expect(listener.components(separatedBy: "connectionEnded(connectionID)").count == 3)
        #expect(listener.contains("connectionSupervision.register(connectionID)"))
        #expect(listener.contains("connectionSupervision.end("))
        #expect(listener.contains("case .restoreOwnedSession:"))
        #expect(!listener.contains("ObjectIdentifier(newConnection)"))
        #expect(!helper.contains("private var activeConnections ="))

        let interruption = try #require(listener.range(
            of: "newConnection.interruptionHandler"
        ))
        let invalidation = try #require(listener.range(
            of: "newConnection.invalidationHandler"
        ))
        let registration = try #require(listener.range(
            of: "connectionSupervision.register(connectionID)"
        ))
        let synchronousRegistration = try #require(listener.range(
            of: "let registered = queue.sync"
        ))
        let collisionCleanup = try #require(listener.range(
            of: "newConnection.interruptionHandler = nil"
        ))
        #expect(listener.contains("newConnection.invalidationHandler = nil"))
        let resume = try #require(listener.range(of: "newConnection.resume()"))
        #expect(interruption.lowerBound < registration.lowerBound)
        #expect(invalidation.lowerBound < registration.lowerBound)
        #expect(synchronousRegistration.lowerBound < registration.lowerBound)
        #expect(registration.lowerBound < resume.lowerBound)
        #expect(registration.lowerBound < collisionCleanup.lowerBound)
        #expect(collisionCleanup.lowerBound < resume.lowerBound)

        let connectionEnd = try section(
            of: helper,
            from: "private func connectionEnded(_ connectionID: UUID)",
            through: "// MARK: - Per-connection XPC facade"
        )
        let stateQueue = try #require(connectionEnd.range(of: "queue.async"))
        let terminalGate = try #require(connectionEnd.range(
            of: "connectionSupervision.end("
        ))
        let restore = try #require(connectionEnd.range(of: "performRestore("))
        #expect(stateQueue.lowerBound < terminalGate.lowerBound)
        #expect(terminalGate.lowerBound < restore.lowerBound)
    }

    @Test func ownerLossRestoresExactlyOnceInEitherCallbackOrder() {
        for _ in ["interruption-first", "invalidation-first"] {
            var supervision = HelperConnectionSupervisionSafety<Int>()
            let registeredOwner = supervision.register(41)
            let registeredPeer = supervision.register(42)
            #expect(registeredOwner)
            #expect(registeredPeer)

            let firstEnd = supervision.end(
                41,
                owner: 41,
                hasActiveSession: true
            )
            let duplicateEnd = supervision.end(
                41,
                owner: 41,
                hasActiveSession: true
            )
            #expect(firstEnd == .restoreOwnedSession)
            #expect(duplicateEnd == .ignoreDuplicate)
            #expect(supervision.activeCount == 1)
            #expect(supervision.contains(42))
        }
    }

    @Test func nonOwnerLossCannotEndOrRenewTheOwner() {
        var supervision = HelperConnectionSupervisionSafety<Int>()
        let registeredOwner = supervision.register(51)
        let registeredPeer = supervision.register(52)
        #expect(registeredOwner)
        #expect(registeredPeer)

        let end = supervision.end(
            52,
            owner: 51,
            hasActiveSession: true
        )
        #expect(end == .connectionEnded)
        #expect(supervision.contains(51))
        #expect(!supervision.contains(52))
        #expect(supervision.activeCount == 1)
    }

    @Test func duplicateRegistrationCannotCreateASecondLiveConnection() {
        var supervision = HelperConnectionSupervisionSafety<Int>()
        let firstRegistration = supervision.register(71)
        let duplicateRegistration = supervision.register(71)

        #expect(firstRegistration)
        #expect(!duplicateRegistration)
        #expect(supervision.activeCount == 1)
    }

    @Test func aTerminalConnectionCannotArmAfterItsLossWasCommitted() {
        var supervision = HelperConnectionSupervisionSafety<Int>()
        let registered = supervision.register(61)
        #expect(registered)
        #expect(supervision.contains(61))
        let end = supervision.end(
            61,
            owner: Optional<Int>.none,
            hasActiveSession: false
        )
        #expect(end == .connectionEnded)
        #expect(!supervision.contains(61))
    }
}
