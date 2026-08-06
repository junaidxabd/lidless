import Foundation
import Testing
@testable import LidlessCore

@Suite("Helper XPC request completion safety")
struct HelperXPCRequestSafetyTests {
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

    private func normalizedWhitespace<S: StringProtocol>(_ source: S) -> String {
        source.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    @Test func exactlyOneTerminalEventCanCompleteARequest() {
        for winner in HelperXPCRequestSafety.Outcome.allCases {
            let completion = HelperXPCRequestSafety.CompletionGate()
            #expect(completion.claim(winner))
            for lateOutcome in HelperXPCRequestSafety.Outcome.allCases {
                #expect(!completion.claim(lateOutcome))
            }
        }
    }

    @Test func concurrentTerminalEventsStillProduceOneWinner() async {
        let completion = HelperXPCRequestSafety.CompletionGate()
        var winnerCount = 0

        await withTaskGroup(of: Bool.self) { group in
            for index in 0..<300 {
                let outcome = HelperXPCRequestSafety.Outcome.allCases[
                    index % HelperXPCRequestSafety.Outcome.allCases.count
                ]
                group.addTask {
                    completion.claim(outcome)
                }
            }
            for await didClaim in group where didClaim {
                winnerCount += 1
            }
        }

        #expect(winnerCount == 1)
    }

    @Test func replyDeadlinePrecedesTheDefaultWatchdogDeadline() {
        #expect(HelperXPCRequestSafety.replyTimeout == 25)
        #expect(HelperXPCRequestSafety.replyTimeout.isFinite)
        #expect(HelperXPCRequestSafety.replyTimeout > 0)
        #expect(
            HelperArmOptions.heartbeatInterval
                + HelperXPCRequestSafety.replyTimeout
                < HelperArmOptions.defaultWatchdogTTL
        )
    }

    @Test func clientTimesOutEveryXPCContinuationAndRetiresItsConnection() throws {
        let client = try repositoryFile("App/Sources/Helper/HelperClient.swift")
        let call = try section(
            of: client,
            from: "    private func call(",
            through: "    private func callForReply("
        )
        let replyDecoderStart = try #require(client.range(
            of: "    private func callForReply("
        ))
        let replyDecoder = client[replyDecoderStart.lowerBound..<client.endIndex]
        let connectionSetup = try section(
            of: client,
            from: "    private func ensureConnection()",
            through: "    private func invalidateConnection()"
        )
        let connectionLoss = try section(
            of: client,
            from: "    private func handleConnectionLoss(",
            through: "    /// Retire the exact connection"
        )
        let retirement = try section(
            of: client,
            from: "    private func retireConnection(",
            through: "    /// One XPC round trip"
        )

        let timer = try #require(call.range(
            of: "DispatchQueue.global().asyncAfter"
        ))
        let proxy = try #require(call.range(
            of: "remoteObjectProxyWithErrorHandler"
        ))
        let dispatch = try #require(call.range(of: "body(proxy)"))
        let timeoutClaim = try #require(call.range(
            of: "completion.claim(.timeout)"
        ))
        let timeoutResume = try #require(call.range(
            of: "HelperClientError.timedOut(timeout)"
        ))
        let timeoutCatch = try #require(call.range(
            of: "catch HelperClientError.timedOut"
        ))
        let retirementCall = try #require(call.range(
            of: "retireConnection(requestConnection)",
            range: timeoutCatch.upperBound..<call.endIndex
        ))
        let timeoutThrow = try #require(call.range(
            of: "throw HelperClientError.timedOut",
            range: retirementCall.upperBound..<call.endIndex
        ))
        let capturedInvalidation = try #require(connectionLoss.range(
            of: "lostConnection.invalidate()"
        ))
        let capturedConnectionCheck = try #require(connectionLoss.range(
            of: "connection === lostConnection",
            range: capturedInvalidation.upperBound..<connectionLoss.endIndex
        ))
        let cachedClear = try #require(connectionLoss.range(
            of: "connection = nil",
            range: capturedConnectionCheck.upperBound..<connectionLoss.endIndex
        ))
        let proofLossNotification = try #require(connectionLoss.range(
            of: "onInterruption?()",
            range: cachedClear.upperBound..<connectionLoss.endIndex
        ))
        let normalizedCall = normalizedWhitespace(call)

        #expect(call.contains(
            "let completion = HelperXPCRequestSafety.CompletionGate()"
        ))
        #expect(call.contains("let timeout = HelperXPCRequestSafety.replyTimeout"))
        #expect(call.contains("asyncAfter(deadline: .now() + timeout)"))
        #expect(normalizedCall.contains(
            "if completion.claim(.timeout) { continuation.resume(throwing: HelperClientError.timedOut(timeout)) }"
        ))
        #expect(normalizedCall.contains(
            "if completion.claim(.transportFailure) { continuation.resume(throwing: error) }"
        ))
        #expect(normalizedCall.contains(
            "if completion.claim(.transportFailure) { continuation.resume(throwing: HelperClientError.badProxy) }"
        ))
        #expect(normalizedCall.contains(
            "if completion.claim(.reply) { continuation.resume(returning: data) }"
        ))
        #expect(call.contains("catch HelperClientError.timedOut"))
        #expect(timer.lowerBound < proxy.lowerBound)
        #expect(timer.lowerBound < dispatch.lowerBound)
        #expect(timeoutClaim.lowerBound < timeoutResume.lowerBound)
        #expect(timeoutCatch.lowerBound < retirementCall.lowerBound)
        #expect(retirementCall.lowerBound < timeoutThrow.lowerBound)
        #expect(retirement.contains("handleConnectionLoss(requestConnection)"))
        #expect(capturedInvalidation.lowerBound < capturedConnectionCheck.lowerBound)
        #expect(capturedConnectionCheck.lowerBound < cachedClear.lowerBound)
        #expect(cachedClear.lowerBound < proofLossNotification.lowerBound)
        #expect(connectionSetup.components(
            separatedBy: "self.handleConnectionLoss(fresh)"
        ).count == 3)
        #expect(connectionSetup.components(
            separatedBy: "guard let self, let fresh else { return }"
        ).count == 3)
        #expect(replyDecoder.contains("let data = try await call(body)"))
        #expect(client.contains("case timedOut(TimeInterval)"))
        #expect(client.contains("The helper request timed out"))
    }
}
