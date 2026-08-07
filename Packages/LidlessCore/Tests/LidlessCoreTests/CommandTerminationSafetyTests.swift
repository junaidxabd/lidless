import Testing
@testable import LidlessCore

@Suite("Command termination safety")
struct CommandTerminationSafetyTests {
    @Test(arguments: [
        (true, true, CommandTerminationSafety.Result.killedAndReaped),
        (false, true, CommandTerminationSafety.Result.exited),
        (true, false, CommandTerminationSafety.Result.unproven),
        (false, false, CommandTerminationSafety.Result.unproven),
    ])
    func timeoutClassification(
        _ killAccepted: Bool,
        _ exitObserved: Bool,
        _ expected: CommandTerminationSafety.Result
    ) {
        #expect(CommandTerminationSafety.classify(
            killAccepted: killAccepted,
            exitObserved: exitObserved
        ) == expected)
    }

    @Test func onlyAnObservedExitResolvesMutationUncertainty() {
        for killAccepted in [false, true] {
            #expect(CommandTerminationSafety.hasUnresolvedMutation(
                killAccepted: killAccepted,
                exitObserved: false
            ))
            #expect(!CommandTerminationSafety.hasUnresolvedMutation(
                killAccepted: killAccepted,
                exitObserved: true
            ))
        }
    }
}
