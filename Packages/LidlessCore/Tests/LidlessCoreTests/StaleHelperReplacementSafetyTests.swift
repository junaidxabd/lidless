import Foundation
import Testing
@testable import LidlessCore

@Suite("Stale helper recovery and admission safety")
struct StaleHelperReplacementSafetyTests {
    private func reply(
        version: Int = LidlessIDs.helperVersion,
        revision: Int?,
        ok: Bool = true,
        armed: Bool = false,
        sleepDisabled: Bool = false,
        sleepStateVerified: Bool? = true,
        restorePending: Bool? = false
    ) -> HelperReply {
        HelperReply(
            ok: ok,
            status: HelperStatus(
                helperVersion: version,
                helperSafetyRevision: revision,
                armed: armed,
                sleepDisabled: sleepDisabled,
                sleepStateVerified: sleepStateVerified,
                restorePending: restorePending
            )
        )
    }

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

    @Test func sameWireVersionMismatchCanOnlyCompleteDeRiskingTwoSourceProof() {
        let revisions: [Int?] = [
            nil,
            6,
            LidlessIDs.helperSafetyRevision - 1,
            LidlessIDs.helperSafetyRevision + 1,
        ]

        for revision in revisions {
            let restored = reply(revision: revision)
            let armed = reply(
                revision: revision,
                armed: true,
                sleepDisabled: true
            )

            #expect(SleepOverrideSafety.isRecoveryCompatibleHelper(restored.status))
            #expect(!SleepOverrideSafety.isCurrentHelper(restored.status))
            #expect(!SleepOverrideSafety.isArmProven(armed.status))
            #expect(!SleepOverrideSafety.isArmProven(armed))
            #expect(!SleepOverrideSafety.isRestoreProven(restored.status))
            #expect(!SleepOverrideSafety.isRestoreProven(restored))

            #expect(SleepOverrideSafety.isRestoreProven(
                restored.status,
                independentlyObserved: false
            ))
            #expect(SleepOverrideSafety.isRestoreProven(
                restored,
                independentlyObserved: false
            ))
            #expect(!SleepOverrideSafety.isRestoreProven(
                restored,
                independentlyObserved: nil
            ))
            #expect(!SleepOverrideSafety.isRestoreProven(
                restored,
                independentlyObserved: true
            ))

            var gate = NonSleepRestoreGate()
            let generation = gate.begin()
            #expect(gate.evaluateBaseProof(
                generation: generation,
                helperReply: restored,
                independentlyObserved: false,
                armRequestsInFlight: 0
            ) == .complete)
            #expect(gate.isCompleted(generation))

        }
    }

    @Test func differentWireVersionCannotSupplyAutomaticRecoveryProof() {
        for version in [
            LidlessIDs.helperVersion - 1,
            LidlessIDs.helperVersion + 1,
        ] {
            let restored = reply(version: version, revision: nil)

            #expect(!SleepOverrideSafety.isRecoveryCompatibleHelper(restored.status))
            #expect(!SleepOverrideSafety.isRestoreProven(
                restored,
                independentlyObserved: false
            ))
            var gate = NonSleepRestoreGate()
            let generation = gate.begin()
            #expect(gate.evaluateBaseProof(
                generation: generation,
                helperReply: restored,
                independentlyObserved: false,
                armRequestsInFlight: 0
            ) == .manualRecoveryRequired)
            #expect(!gate.owns(generation))
        }
    }

    @Test func publicCleanupIsUnavailableForEveryRevision() throws {
        let client = try repositoryFile("App/Sources/Helper/HelperClient.swift")
        let uninstall = try section(
            of: client,
            from: "func uninstall() async throws {",
            through: "// MARK: - XPC surface"
        )

        #expect(uninstall.contains("Automatic helper cleanup is disabled"))
        #expect(uninstall.contains("Keep the helper registered"))
        #expect(!uninstall.contains("await"))
        #expect(!uninstall.contains("unregister"))
        #expect(!client.contains("isReviewedCleanupCompatibleHelper"))
        #expect(!client.contains("reviewedStaleReplacementSafetyRevision"))
    }

    @Test func malformedStaleRestoreCannotBorrowIndependentRegistryProof() {
        let rejected = [
            reply(revision: 6, ok: false),
            reply(revision: 6, armed: true),
            reply(revision: 6, sleepDisabled: true),
            reply(revision: 6, sleepStateVerified: nil),
            reply(revision: 6, sleepStateVerified: false),
            reply(revision: 6, restorePending: nil),
            reply(revision: 6, restorePending: true),
        ]

        for candidate in rejected {
            #expect(!SleepOverrideSafety.isRestoreProven(
                candidate,
                independentlyObserved: false
            ))
        }
    }

    @Test func failedArmMayUseStructuralStaleStatusDespiteANegativeOperationResult() {
        for revision: Int? in [
            nil,
            6,
            LidlessIDs.helperSafetyRevision - 1,
        ] {
            let negativeReply = reply(revision: revision, ok: false)

            // Operation completion still requires `ok`, while failed-arm
            // disposition deliberately asks only whether two fresh sources
            // already prove the machine is back to normal sleep.
            #expect(!SleepOverrideSafety.isRestoreProven(
                negativeReply,
                independentlyObserved: false
            ))
            #expect(SleepOverrideSafety.isRestoreProven(
                negativeReply.status,
                independentlyObserved: false
            ))
            #expect(SleepOverrideSafety.failedArmDisposition(
                negativeReply,
                independentlyObserved: false
            ) == .alreadyRestored)
        }
    }

    /// The install-state refresh classifies live helper status *inside* the
    /// client, so the app never observes that `HelperStatus` directly. It is
    /// still an accepted live-evidence ingress and must cross the same wake
    /// admission boundary: a classification that is not exact-current `.ready`
    /// (or `.simulated`) can never retain cached scheduled-wake authority.
    @Test func installStateRefreshCrossesTheSharedWakeAdmissionBoundary() throws {
        let app = try repositoryFile("App/Sources/AppState.swift")

        let refresh = try section(
            of: app,
            from: "private func refreshHelperInstallState() async -> Bool {",
            through: "private func retainRecoveryOnlyHelperStateIfNeeded("
        )
        let classification = try #require(refresh.range(
            of: "await helper.refreshInstallState()"
        ))
        let admission = try #require(refresh.range(
            of: "retainRecoveryOnlyHelperStateIfNeeded()",
            range: classification.upperBound..<refresh.endIndex
        ))
        let successReturn = try #require(refresh.range(
            of: "return true",
            range: classification.upperBound..<refresh.endIndex
        ))
        #expect(classification.lowerBound < admission.lowerBound)
        #expect(admission.lowerBound < successReturn.lowerBound)

        // One shared primitive, not a second copy of the demotion rule: the
        // status-bearing entry point must delegate to the same boundary after
        // demoting the client, so both ingresses retire wake authority
        // through exactly one `isUsable` decision.
        let admissionBoundary = try section(
            of: app,
            from: "private func retainRecoveryOnlyHelperStateIfNeeded(",
            through: "private func stopAutomaticRecoveryForIncompatibleWire("
        )
        let demotion = try #require(admissionBoundary.range(
            of: "helper.recordRecoveryOnlyStatus(status)"
        ))
        let delegation = try #require(admissionBoundary.range(
            of: "retainRecoveryOnlyHelperStateIfNeeded()",
            range: demotion.upperBound..<admissionBoundary.endIndex
        ))
        let usableCheck = try #require(admissionBoundary.range(
            of: "guard !helperState.isUsable else { return }",
            range: delegation.upperBound..<admissionBoundary.endIndex
        ))
        let invalidation = try #require(admissionBoundary.range(
            of: "scheduledWakeReconciliation.invalidate()",
            range: usableCheck.upperBound..<admissionBoundary.endIndex
        ))
        #expect(demotion.lowerBound < delegation.lowerBound)
        #expect(usableCheck.lowerBound < invalidation.lowerBound)

        let architecture = try repositoryFile("ARCHITECTURE.md")
        #expect(architecture.contains(
            "including a refresh the client classifies itself"
        ))

        // The launch exclusion must be released after the decision/demotion
        // but before launch wake maintenance, or that call silently blocks on
        // this function's own in-flight guard and does nothing.
        let reconcile = try section(
            of: app,
            from: "private func reconcileWithHelper() async {",
            through: "// MARK: - Tick loop"
        )
        let inFlightSet = try #require(reconcile.range(
            of: "launchReconciliationInFlight = true"
        ))
        let statusAwait = try #require(reconcile.range(
            of: "try? await helper.status()"
        ))
        let launchDemotion = try #require(reconcile.range(
            of: "retainRecoveryOnlyHelperStateIfNeeded(status)"
        ))
        let exclusionRelease = try #require(reconcile.range(
            of: "launchReconciliationInFlight = false",
            range: launchDemotion.upperBound..<reconcile.endIndex
        ))
        let launchWakeMaintenance = try #require(reconcile.range(
            of: "maintainScheduledWake()"
        ))
        #expect(inFlightSet.lowerBound < statusAwait.lowerBound)
        #expect(launchDemotion.lowerBound < exclusionRelease.lowerBound)
        #expect(exclusionRelease.lowerBound < launchWakeMaintenance.lowerBound)
    }

    /// Terminalizing an incompatible-wire generation deliberately preserves
    /// `pendingRestore` and leaves `phase == .disarming`, so the fence cannot be
    /// represented by the *absence* of a monitor task: any later helper-proof
    /// loss restarts one from exactly that state and re-dispatches unsupported
    /// mutations in a 5-second loop. The fence must be an explicit latch that
    /// every monitor entry point consults.
    @Test func incompatibleWireFenceSurvivesRestoreMonitorRestart() throws {
        let app = try repositoryFile("App/Sources/AppState.swift")

        #expect(app.contains(
            "private var manualRecoveryGeneration: NonSleepRestoreGeneration?"
        ))

        let fence = try section(
            of: app,
            from: "private func stopAutomaticRecoveryForIncompatibleWire(",
            through: "private func recordSleepTransition()"
        )
        let latch = try #require(fence.range(
            of: "manualRecoveryGeneration = restoreID"
        ))
        let monitorStop = try #require(fence.range(of: "stopRestoreMonitor()"))
        #expect(latch.lowerBound < monitorStop.lowerBound)

        // The restart entry point must refuse a fenced generation...
        let start = try section(
            of: app,
            from: "private func startRestoreMonitor(",
            through: "private func runRestoreMonitor("
        )
        #expect(start.contains("manualRecoveryGeneration != restoreID"))

        // ...and the loop itself must exit if it is already running.
        let monitor = try section(
            of: app,
            from: "private func runRestoreMonitor(",
            through: "private func dispatchForceSleepFollowUp("
        )
        let loopGuard = try #require(monitor.range(
            of: "manualRecoveryGeneration != restoreID"
        ))
        let dispatch = try #require(monitor.range(
            of: "reply = try await helper.disarm(pending.options)"
        ))
        #expect(loopGuard.lowerBound < dispatch.lowerBound)

        let architecture = try repositoryFile("ARCHITECTURE.md")
        #expect(architecture.contains("absence of a monitor task is not a fence"))
    }

    /// After the fence engages, `.disarming` no longer means work is in
    /// progress. The quit refusal must not tell the user to wait for a
    /// verification Lidless has stopped attempting.
    @Test func quitRefusalTellsTheTruthAfterAutomaticRecoveryStopped() throws {
        let app = try repositoryFile("App/Sources/AppState.swift")
        let entry = try repositoryFile("App/Sources/LidlessApp.swift")

        #expect(app.contains("var automaticRecoveryStopped: Bool"))
        #expect(entry.contains("state.automaticRecoveryStopped"))
        #expect(entry.contains("stopped automatic recovery"))
        // The honest boundary: no promise that quitting will succeed later.
        #expect(!entry.contains("then quit again"))
    }

    /// The sleep-transition fence has no restore generation to latch — that
    /// path already nilled `pendingRestore` — so a generation-keyed latch alone
    /// reports "recovery still running" for a state that is just as terminally
    /// fenced, and the quit handler then overwrites the fence's own message
    /// with the false one. The sleep generation is the self-invalidating key
    /// for that path: `recordSleepTransition` bumps it, so a later transition
    /// cannot inherit a stale latch.
    @Test func sleepTransitionFenceIsAlsoReportedAsStoppedRecovery() throws {
        let app = try repositoryFile("App/Sources/AppState.swift")

        #expect(app.contains(
            "private var manualRecoverySleepGeneration: UInt64?"
        ))
        let fence = try section(
            of: app,
            from: "private func stopAutomaticRecoveryForIncompatibleWire(",
            through: "private func recordSleepTransition()"
        )
        #expect(fence.contains("manualRecoverySleepGeneration = sleepGeneration"))

        // Both branches must be reachable from the quit boundary.
        let stopped = try section(
            of: app,
            from: "var automaticRecoveryStopped: Bool {",
            through: "private func stopAutomaticRecoveryForIncompatibleWire("
        )
        #expect(stopped.contains("manualRecoveryGeneration == pending.id"))
        #expect(stopped.contains(
            "manualRecoverySleepGeneration == sleepGeneration"
        ))

        // The key must be bumped on every new transition so it self-expires.
        let transition = try section(
            of: app,
            from: "private func recordSleepTransition()",
            through: "private func scheduleSleepTerminationRestore()"
        )
        #expect(transition.contains("sleepGeneration &+= 1"))

        let architecture = try repositoryFile("ARCHITECTURE.md")
        #expect(architecture.contains(
            "keyed on the sleep generation instead"
        ))
    }

    /// The fenced quit boundary must not imply a resolvable condition it has
    /// no route to resolve. Nothing in-app clears the fenced state, so the copy
    /// has to name the only real exit and say what it does not change.
    @Test func fencedQuitCopyNamesTheOnlyRealExit() throws {
        let entry = try repositoryFile("App/Sources/LidlessApp.swift")
        #expect(entry.contains("Force-quitting"))
        #expect(!entry.contains("Quitting stays blocked while this session is unresolved"))

        // The incompatible responder cannot be trusted to honor the current
        // connection-loss contract. Copy must describe force-quit as an
        // unverified state change, never as recovery proof or a safe remedy.
        #expect(!entry.contains("will not change the current sleep setting"))
        #expect(entry.contains("Force-quitting ends app-side verification"))
        #expect(entry.contains("it is not proof of recovery"))
        #expect(entry.contains("may change helper behavior"))
        // The fenced responder's wire protocol is by definition unverifiable,
        // so the copy must not assert what this particular helper will do.
        #expect(!entry.contains("the helper's own watchdog"))

        // The copy lives in `lastError`, which Overview does not render — and
        // Overview is the default pane. Opening the window without naming a
        // pane shows only the `.restoring` hero ("Restoring sleep…"), which is
        // the exact false impression this fence exists to remove. Both fence
        // surfaces must route to the pane that renders `lastError` and holds
        // the emergency command the copy tells the user to run.
        #expect(entry.contains("requestMainWindow(pane: .setup)"))
        #expect(!entry.contains("state.requestMainWindow()"))

        let app = try repositoryFile("App/Sources/AppState.swift")
        let fence = try section(
            of: app,
            from: "private func stopAutomaticRecoveryForIncompatibleWire(",
            through: "private func recordSleepTransition()"
        )
        #expect(fence.contains("requestMainWindow(pane: .setup)"))
        #expect(!fence.contains("requestMainWindow()"))

        // Same self-consistency rule for the copy that says "Open Setup".
        let repair = try section(
            of: app,
            from: "func repairOverride() async",
            through: "func installHelper() async"
        )
        #expect(!repair.contains("Open Setup for emergency sleep recovery. Keep the helper registered and contact Lidless support for a separately reviewed removal procedure.\"\n            requestMainWindow()"))
        #expect(repair.contains("requestMainWindow(pane: .setup)"))

        // Public cleanup is now an unconditional mutation-free refusal, so it
        // cannot misdescribe a fenced recovery state or drop supervision.
        let uninstall = try section(
            of: app,
            from: "func uninstall() async -> String?",
            through: "// MARK: - Login item"
        )
        #expect(uninstall.contains("Automatic helper cleanup is disabled"))
        #expect(uninstall.contains("No state was changed"))
        #expect(!uninstall.contains("await"))
        #expect(!uninstall.contains("automaticRecoveryStopped"))
    }

    /// The monitor's post-sleep guard must re-check the fence itself rather
    /// than relying on an external `stopRestoreMonitor()` cancellation.
    @Test func restoreMonitorIsSelfFencingAcrossItsRetryDelay() throws {
        let app = try repositoryFile("App/Sources/AppState.swift")
        let monitor = try section(
            of: app,
            from: "private func runRestoreMonitor(",
            through: "private func dispatchForceSleepFollowUp("
        )
        let sleepCall = try #require(monitor.range(of: "Task.sleep(for: .seconds(5))"))
        let postSleepGuard = try #require(monitor.range(
            of: "manualRecoveryGeneration != restoreID",
            range: sleepCall.upperBound..<monitor.endIndex
        ))
        let dispatch = try #require(monitor.range(
            of: "reply = try await helper.disarm(pending.options)"
        ))
        #expect(postSleepGuard.lowerBound < dispatch.lowerBound)
    }

    /// `.unknown` is a legitimate intermediate value during a user-initiated
    /// helper lifecycle operation. Surfacing it there would flash a terminal
    /// warning mid-operation.
    @Test func terminalHelperBannerIsQuietDuringHelperLifecycleWork() throws {
        let menu = try repositoryFile("App/Sources/UI/MenuBar/MenuPanelView.swift")
        #expect(menu.contains("!state.helperLifecycleWorkInProgress"))
        let app = try repositoryFile("App/Sources/AppState.swift")
        #expect(app.contains("var helperLifecycleWorkInProgress: Bool"))
        // Scoped to the install/replace/remove flows, which really do pass
        // through intermediate unclassified states. A plain status refresh
        // writes `installState` once, at the end, so folding its in-flight
        // counter in here would mute a genuine warning for the whole XPC
        // timeout — longest exactly when the helper is wedged.
        let scope = try section(
            of: app,
            from: "var helperLifecycleWorkInProgress: Bool {",
            through: "private func refreshHelperInstallState()"
        )
        #expect(!scope.contains("helperLifecycleOperationsInFlight"))
    }

    /// The shipped client has no automatic cleanup execution path. Its public
    /// compatibility method refuses synchronously and keeps launchd recovery
    /// supervision intact.
    @Test func removalEntryPointIsAnUnconditionalRefusal() throws {
        let client = try repositoryFile("App/Sources/Helper/HelperClient.swift")
        let uninstall = try section(
            of: client,
            from: "func uninstall() async throws {",
            through: "// MARK: - XPC surface"
        )
        #expect(uninstall.contains("throw HelperClientError.rejected("))
        #expect(uninstall.contains("Automatic helper cleanup is disabled"))
        #expect(uninstall.contains("Keep the helper registered"))
        #expect(!uninstall.contains("await"))
        #expect(!uninstall.contains("commitUninstall"))
        #expect(!uninstall.contains("unregister"))
        #expect(!client.contains("private func uninstall("))
        #expect(!client.contains("unregisterDaemon"))
    }

    /// `.unknown` is now a concluded verdict, so the surfaces that were written
    /// when it meant "not yet checked" must stop hiding it. Only `.checking` is
    /// pre-classification.
    @Test func concludedUnknownIsNotSuppressedAsUnclassified() throws {
        let app = try repositoryFile("App/Sources/AppState.swift")
        let menu = try repositoryFile("App/Sources/UI/MenuBar/MenuPanelView.swift")

        #expect(!app.contains("helperState != .unknown"))
        #expect(!menu.contains("state.helperState != .unknown"))
        #expect(app.contains("helperState != .checking"))
        #expect(menu.contains("state.helperState != .checking"))
        // The banner must not call an unverifiable helper a setup chore: it
        // needs its own arm rather than the generic setup fallback, and the
        // action must not imply a one-tap fix that does not exist.
        #expect(menu.contains("case .unknown:"))
        #expect(menu.contains("unverified"))
        let bannerMessage = try section(
            of: menu,
            from: "private var helperBannerMessage: String {",
            through: "// MARK: Proof summary"
        )
        let unknownArm = try #require(bannerMessage.range(of: "case .unknown:"))
        let genericFallback = try #require(bannerMessage.range(
            of: "default:\n            \"Helper setup is required.\""
        ))
        #expect(unknownArm.lowerBound < genericFallback.lowerBound)
        #expect(menu.contains("helperBannerIsTerminal"))
        #expect(menu.contains("\"Open Setup…\""))
    }

    /// Every stale revision is terminal because no public replacement path is
    /// shipped. None may be dressed as retryable progress.
    @Test func terminalStaleRevisionIsNotRenderedAsRetryableProgress() throws {
        let setup = try repositoryFile("App/Sources/UI/Main/SetupPane.swift")
        let icon = try section(
            of: setup,
            from: "private var statusIcon: some View {",
            through: "private var statusTitle: String {"
        )
        #expect(icon.contains(
            "case .stale:\n"
                + "                Image(systemName: \"exclamationmark.triangle.fill\")"
        ))
        #expect(!icon.contains("arrow.triangle.2.circlepath"))
        #expect(!setup.contains("isReviewedStaleReplacementCompatible("))
        #expect(setup.contains("Public replacement disabled"))
    }

    /// A stale helper must not expose a one-click replace/remove action because
    /// no automatic cleanup procedure is shipped.
    @Test func replacementSurfacesExposeNoDestructiveAction() throws {
        let setup = try repositoryFile("App/Sources/UI/Main/SetupPane.swift")
        let onboarding = try repositoryFile(
            "App/Sources/UI/Onboarding/OnboardingView.swift"
        )

        for surface in [setup, onboarding] {
            #expect(!surface.contains("Replace Helper"))
            #expect(!surface.contains("Remove Helper"))
            #expect(!surface.contains("state.uninstall"))
            #expect(surface.contains("reviewed procedure"))
        }
    }

    /// A responder that replies `ok: true` may have applied the RTC wake even
    /// though this app refuses its revision. That is an indeterminate remote
    /// outcome, not an explicit negative reply, and only `.uncertain` sets the
    /// ordering hazard that prevents a later false confirmation.
    @Test func nonCurrentScheduledWakeSuccessIsIndeterminateNotRejected() throws {
        let client = try repositoryFile("App/Sources/Helper/HelperClient.swift")
        let scheduleWake = try section(
            of: client,
            from: "func scheduleWake(_ date: Date?) async throws {",
            through: "// MARK: - Connection plumbing"
        )
        // An explicit negative reply stays `.rejected`; a refused-but-possibly
        // applied reply must not reuse that error case.
        #expect(scheduleWake.contains("guard reply.ok else"))
        #expect(scheduleWake.contains("HelperClientError.outcomeUnknown"))
        #expect(client.contains("case outcomeUnknown"))

        // AppState maps every non-`.rejected` failure to `.uncertain`.
        let app = try repositoryFile("App/Sources/AppState.swift")
        #expect(app.contains("catch HelperClientError.rejected(_) {"))
        #expect(app.contains("outcome: .uncertain"))

        var reconciliation = ScheduledWakeReconciliation()
        let wake = Date(timeIntervalSince1970: 1_800_000_000)
        let started = reconciliation.begin(desired: wake)
        let request = try #require(started)
        reconciliation.complete(request.id, outcome: .uncertain)
        #expect(reconciliation.hasUnresolvedOrderingHazard)
        #expect(!reconciliation.isConfirmed(desired: wake))

        // The same reply classified as `.rejected` would leave no hazard.
        var rejecting = ScheduledWakeReconciliation()
        let startedRejecting = rejecting.begin(desired: wake)
        let rejected = try #require(startedRejecting)
        rejecting.complete(rejected.id, outcome: .rejected)
        #expect(!rejecting.hasUnresolvedOrderingHazard)

        let architecture = try repositoryFile("ARCHITECTURE.md")
        #expect(architecture.contains(
            "refused after delivery is an indeterminate remote outcome"
        ))
    }

    /// A failed arm whose reply lost ownership validation is still *consumed*:
    /// `failedArmDisposition` can disarm the phase or start recovery from it,
    /// because a failed arm may have partially applied and must never be left
    /// unrecovered. Since the reply is consumed, it has to cross the admission
    /// boundary first. The boundary only demotes and a live re-classification
    /// follows immediately, so crossing it for a superseded reply is the
    /// fail-closed direction.
    @Test func failedArmDispositionCannotConsumeAnUnadmittedReply() throws {
        let app = try repositoryFile("App/Sources/AppState.swift")
        let confirmArm = try section(
            of: app,
            from: "func confirmArm(expectedIntentID: UUID) async",
            through: "func disarm() async"
        )

        // The demotion must not be gated on the ownership result, or a
        // superseded reply reaches the disposition without being admitted.
        #expect(!confirmArm.contains(
            "if responseIsOwned {\n"
                + "                retainRecoveryOnlyHelperStateIfNeeded(reply.status)\n"
                + "            }"
        ))
        let ownership = try #require(confirmArm.range(
            of: "let responseIsOwned = phase == .arming"
        ))
        let demotion = try #require(confirmArm.range(
            of: "retainRecoveryOnlyHelperStateIfNeeded(reply.status)"
        ))
        let ownershipGuard = try #require(confirmArm.range(
            of: "guard responseIsOwned,",
            range: ownership.upperBound..<confirmArm.endIndex
        ))
        let disposition = try #require(confirmArm.range(
            of: "SleepOverrideSafety.failedArmDisposition("
        ))
        // Ownership is still computed first — the boundary is crossed after
        // generation/ownership validation, before the guard consumes it.
        #expect(ownership.lowerBound < demotion.lowerBound)
        #expect(demotion.lowerBound < ownershipGuard.lowerBound)
        #expect(demotion.lowerBound < disposition.lowerBound)
    }

    /// `.unknown` is a *classified* verdict — ServiceManagement `.notFound`,
    /// a different-wire demotion, or an ambiguous terminal outcome. A freshly
    /// launched app has classified nothing yet, so rendering it with the
    /// terminal unverified/emergency-recovery copy is a false claim. The two
    /// must be distinct states.
    @Test func initialHelperClassificationIsDistinctFromAClassifiedUnknown() throws {
        let client = try repositoryFile("App/Sources/Helper/HelperClient.swift")
        let setup = try repositoryFile("App/Sources/UI/Main/SetupPane.swift")
        let onboarding = try repositoryFile(
            "App/Sources/UI/Onboarding/OnboardingView.swift"
        )

        #expect(client.contains("case checking"))
        #expect(client.contains(
            "private(set) var installState: HelperInstallState = .checking"
        ))
        #expect(!client.contains(
            "private(set) var installState: HelperInstallState = .unknown"
        ))
        // Never a classification result: only the pre-classification value.
        #expect(!client.contains("installState = .checking"))

        // The unclassified state may show progress; the classified verdict
        // must keep its terminal copy and its truthful Re-check action.
        #expect(setup.contains("case .checking: \"Checking…\""))
        #expect(setup.contains("case .checking:\n            ProgressView()"))
        #expect(setup.contains("case .unknown: \"Helper status unverified\""))
        #expect(setup.contains("case .unknown:\n            Button(\"Re-check\")"))
        #expect(onboarding.contains("case .checking:"))
        #expect(onboarding.contains("case .checking: \"Checking helper\""))
        #expect(onboarding.contains("case .unknown: \"Helper status is unverified\""))

        // The unclassified state is never usable, reachable, or eligible for
        // de-risking recovery dispatch.
        let stateEnum = try section(
            of: client,
            from: "enum HelperInstallState: Equatable {",
            through: "/// Everything the app needs from the privileged side"
        )
        #expect(!stateEnum.contains("case .ready, .simulated, .checking"))
        #expect(!stateEnum.contains("case .checking, .ready"))
        #expect(!stateEnum.contains("case .ready, .stale, .simulated, .checking"))

        // Both `install()` classification switches must fail closed on the
        // unclassified value rather than install, replace, or claim success.
        let install = try section(
            of: client,
            from: "func install() async throws {",
            through: "func openApprovalSettings()"
        )
        #expect(install.contains("case .checking:"))
        #expect(install.contains("did not install, replace, or remove anything"))
        #expect(install.contains("will not claim installation succeeded"))

        let architecture = try repositoryFile("ARCHITECTURE.md")
        #expect(architecture.contains(
            "not-yet-classified state is distinct from that verdict"
        ))
    }

    @Test func appRecoveryUsesTheNarrowCompatibilityBoundaryWhileReplacementStaysDisabled() throws {
        let client = try repositoryFile("App/Sources/Helper/HelperClient.swift")
        let app = try repositoryFile("App/Sources/AppState.swift")
        let setup = try repositoryFile("App/Sources/UI/Main/SetupPane.swift")
        let onboarding = try repositoryFile(
            "App/Sources/UI/Onboarding/OnboardingView.swift"
        )
        let architecture = try repositoryFile("ARCHITECTURE.md")

        let install = try section(
            of: client,
            from: "func install() async throws {",
            through: "func openApprovalSettings()"
        )
        let uninstall = try section(
            of: client,
            from: "func uninstall() async throws {",
            through: "// MARK: - XPC surface"
        )
        let repair = try section(
            of: app,
            from: "func repairOverride() async",
            through: "func installHelper() async"
        )
        let appInstall = try section(
            of: app,
            from: "func installHelper() async",
            through: "func refreshHelperState() async"
        )
        let sleepTransitionRestore = try section(
            of: app,
            from: "private func restoreAfterSleepTransition()",
            through: "var effectiveConfig"
        )
        let restoreMonitor = try section(
            of: app,
            from: "private func runRestoreMonitor(",
            through: "private func dispatchForceSleepFollowUp("
        )
        let forceSleepFollowUp = try section(
            of: app,
            from: "private func dispatchForceSleepFollowUp(",
            through: "private func markForceSleepFollowUpSkipped("
        )
        let quitVerification = try section(
            of: app,
            from: "private func verifyQuitAtTerminationBoundary(",
            through: "private func completePendingRestore("
        )
        let confirmArm = try section(
            of: app,
            from: "func confirmArm(expectedIntentID: UUID) async",
            through: "func disarm() async"
        )
        let heartbeat = try section(
            of: app,
            from: "private func startHeartbeat()",
            through: "private func stopHeartbeat()"
        )
        let wakeAdmission = try section(
            of: app,
            from: "private func retainRecoveryOnlyHelperStateIfNeeded(",
            through: "private func stopAutomaticRecoveryForIncompatibleWire("
        )

        let freshClassification = try #require(install.range(
            of: "await refreshInstallState()"
        ))
        let staleRefusal = try #require(install.range(
            of: "case .stale(let helperVersion, let helperSafetyRevision):"
        ))
        let registration = try #require(install.range(
            of: "try service.register()"
        ))
        #expect(freshClassification.lowerBound < staleRefusal.lowerBound)
        #expect(staleRefusal.lowerBound < registration.lowerBound)
        #expect(install.contains("Automatic replacement and cleanup are disabled"))
        #expect(!install.contains("await uninstall("))
        #expect(!install.contains("HelperCleanupTarget"))
        #expect(install.contains("LidlessIDs.manualFallbackCommand"))
        #expect(install.contains("case .ready, .simulated:"))
        #expect(install.contains("case .requiresApproval:"))

        #expect(uninstall.contains("throw HelperClientError.rejected("))
        #expect(uninstall.contains("Automatic helper cleanup is disabled"))
        #expect(!uninstall.contains("await"))
        #expect(!uninstall.contains("commitUninstall"))
        #expect(!uninstall.contains("unregister"))

        #expect(repair.contains("await refreshHelperInstallState()"))
        #expect(repair.contains("helperState.isRecoveryUsable"))
        #expect(appInstall.contains("lastError = nil"))
        let wakeInvalidation = try #require(appInstall.range(
            of: "scheduledWakeReconciliation.invalidate()"
        ))
        let installDispatch = try #require(appInstall.range(
            of: "try await helper.install()"
        ))
        let wakeMaintenance = try #require(appInstall.range(
            of: "maintainScheduledWake()"
        ))
        #expect(wakeInvalidation.lowerBound < installDispatch.lowerBound)
        let lifecycleRelease = try #require(appInstall.range(
            of: "endHelperLifecycleOperation()"
        ))
        let exclusionRelease = try #require(appInstall.range(
            of: "helperRegistrationInProgress = false"
        ))
        #expect(wakeInvalidation.lowerBound < lifecycleRelease.lowerBound)
        #expect(lifecycleRelease.lowerBound < exclusionRelease.lowerBound)
        #expect(exclusionRelease.lowerBound < wakeMaintenance.lowerBound)
        #expect(wakeMaintenance.lowerBound < installDispatch.lowerBound)
        #expect(sleepTransitionRestore.contains(
            "SleepOverrideSafety.isRestoreProven("
        ))
        #expect(sleepTransitionRestore.contains(
            "independentlyObserved: independentlyObserved"
        ))
        #expect(wakeAdmission.contains(
            "if !SleepOverrideSafety.isCurrentHelper(status) {"
        ))
        // The client demotion must land before the shared boundary reads
        // `helperState`, so one `isUsable` decision retires wake authority for
        // both the status-bearing and the client-classified ingress.
        let helperStateDemotion = try #require(wakeAdmission.range(
            of: "helper.recordRecoveryOnlyStatus(status)"
        ))
        let wakeCacheInvalidation = try #require(wakeAdmission.range(
            of: "scheduledWakeReconciliation.invalidate()"
        ))
        #expect(helperStateDemotion.lowerBound < wakeCacheInvalidation.lowerBound)

        let transitionFence = try #require(sleepTransitionRestore.range(
            of: "guard terminalGeneration == sleepTerminationGeneration else"
        ))
        let transitionDemotion = try #require(sleepTransitionRestore.range(
            of: "retainRecoveryOnlyHelperStateIfNeeded(reply.status)"
        ))
        let transitionCompatibilityGate = try #require(sleepTransitionRestore.range(
            of: "if !SleepOverrideSafety.isRecoveryCompatibleHelper(reply.status)"
        ))
        let transitionProof = try #require(sleepTransitionRestore.range(
            of: "if SleepOverrideSafety.isRestoreProven("
        ))
        let transitionFinalization = try #require(sleepTransitionRestore.range(
            of: "finalizeSession(endReason: .systemSlept)"
        ))
        #expect(transitionFence.lowerBound < transitionDemotion.lowerBound)
        #expect(transitionDemotion.lowerBound < transitionCompatibilityGate.lowerBound)
        #expect(transitionDemotion.lowerBound < transitionProof.lowerBound)
        #expect(transitionDemotion.lowerBound < transitionFinalization.lowerBound)

        let monitorDispatch = try #require(restoreMonitor.range(
            of: "reply = try await helper.disarm(pending.options)"
        ))
        let monitorFence = try #require(restoreMonitor.range(
            of: "guard pendingRestore?.id == restoreID else",
            range: monitorDispatch.upperBound..<restoreMonitor.endIndex
        ))
        let monitorDemotion = try #require(restoreMonitor.range(
            of: "retainRecoveryOnlyHelperStateIfNeeded(reply.status)"
        ))
        let unownedRestoreGate = try #require(restoreMonitor.range(
            of: "switch restoreGate.completeUnownedExternalOverride("
        ))
        let baseRestoreGate = try #require(restoreMonitor.range(
            of: "switch restoreGate.evaluateBaseProof("
        ))
        let monitorCompletion = try #require(restoreMonitor.range(
            of: "completePendingRestore(expectedID: restoreID)"
        ))
        #expect(monitorDispatch.lowerBound < monitorFence.lowerBound)
        #expect(monitorFence.lowerBound < monitorDemotion.lowerBound)
        #expect(monitorDemotion.lowerBound < unownedRestoreGate.lowerBound)
        #expect(monitorDemotion.lowerBound < baseRestoreGate.lowerBound)
        #expect(monitorDemotion.lowerBound < monitorCompletion.lowerBound)

        let followUpDispatch = try #require(forceSleepFollowUp.range(
            of: "let reply = try await helper.disarm(followUp)"
        ))
        let followUpFence = try #require(forceSleepFollowUp.range(
            of: "guard pendingRestore?.id == restoreID else",
            range: followUpDispatch.upperBound..<forceSleepFollowUp.endIndex
        ))
        let followUpDemotion = try #require(forceSleepFollowUp.range(
            of: "retainRecoveryOnlyHelperStateIfNeeded(reply.status)"
        ))
        let followUpGate = try #require(forceSleepFollowUp.range(
            of: "switch restoreGate.evaluateFollowUpProof("
        ))
        let followUpCompletion = try #require(forceSleepFollowUp.range(
            of: "completePendingRestore(expectedID: restoreID)"
        ))
        #expect(followUpDispatch.lowerBound < followUpFence.lowerBound)
        #expect(followUpFence.lowerBound < followUpDemotion.lowerBound)
        #expect(followUpDemotion.lowerBound < followUpGate.lowerBound)
        #expect(followUpDemotion.lowerBound < followUpCompletion.lowerBound)

        let quitDispatch = try #require(quitVerification.range(
            of: "let reply = try await helper.disarm(pending.options)"
        ))
        let quitFence = try #require(quitVerification.range(
            of: "guard terminationPending,",
            range: quitDispatch.upperBound..<quitVerification.endIndex
        ))
        let quitDemotion = try #require(quitVerification.range(
            of: "retainRecoveryOnlyHelperStateIfNeeded(reply.status)"
        ))
        let quitGate = try #require(quitVerification.range(
            of: "switch restoreGate.evaluateFinalProof("
        ))
        let quitCompletion = try #require(quitVerification.range(
            of: "completePendingRestore(expectedID: restoreID)"
        ))
        #expect(quitDispatch.lowerBound < quitFence.lowerBound)
        #expect(quitFence.lowerBound < quitDemotion.lowerBound)
        #expect(quitDemotion.lowerBound < quitGate.lowerBound)
        #expect(quitDemotion.lowerBound < quitCompletion.lowerBound)

        let armDispatch = try #require(confirmArm.range(
            of: "let reply = try await trackedArm(options)"
        ))
        let armFence = try #require(confirmArm.range(
            of: "armProofEpoch == helperProofEpoch",
            range: armDispatch.upperBound..<confirmArm.endIndex
        ))
        let armDemotion = try #require(confirmArm.range(
            of: "retainRecoveryOnlyHelperStateIfNeeded(reply.status)"
        ))
        let armProof = try #require(confirmArm.range(
            of: "SleepOverrideSafety.isArmProven(reply)"
        ))
        let failedArmGate = try #require(confirmArm.range(
            of: "SleepOverrideSafety.failedArmDisposition("
        ))
        #expect(armDispatch.lowerBound < armFence.lowerBound)
        #expect(armFence.lowerBound < armDemotion.lowerBound)
        #expect(armDemotion.lowerBound < armProof.lowerBound)
        #expect(armDemotion.lowerBound < failedArmGate.lowerBound)

        let heartbeatDispatch = try #require(heartbeat.range(
            of: "self.helper.heartbeat()"
        ))
        let heartbeatFence = try #require(heartbeat.range(
            of: "self.heartbeatGeneration == generation",
            range: heartbeatDispatch.upperBound..<heartbeat.endIndex
        ))
        let heartbeatDemotion = try #require(heartbeat.range(
            of: "self.retainRecoveryOnlyHelperStateIfNeeded(reply.status)"
        ))
        let heartbeatProof = try #require(heartbeat.range(
            of: "SleepOverrideSafety.isArmProven(reply)"
        ))
        #expect(heartbeatDispatch.lowerBound < heartbeatFence.lowerBound)
        #expect(heartbeatFence.lowerBound < heartbeatDemotion.lowerBound)
        #expect(heartbeatDemotion.lowerBound < heartbeatProof.lowerBound)
        #expect(app.contains("helper.recordRecoveryOnlyStatus(status)"))
        #expect(app.contains("stopAutomaticRecoveryForIncompatibleWire("))
        let incompatibleReplyLatch = try #require(sleepTransitionRestore.range(
            of: "sleepTerminationIncompatibleWireStatus = reply.status"
        ))
        let incompatibleArmFence = try #require(sleepTransitionRestore.range(
            of: "if armRequestsInFlight == 0,",
            range: incompatibleReplyLatch.upperBound..<sleepTransitionRestore.endIndex
        ))
        let incompatibleStop = try #require(sleepTransitionRestore.range(
            of: "stopAutomaticRecoveryForIncompatibleWire(reply.status)",
            range: incompatibleArmFence.upperBound..<sleepTransitionRestore.endIndex
        ))
        #expect(incompatibleArmFence.lowerBound < incompatibleStop.lowerBound)
        #expect(app.contains(
            "private var sleepTerminationIncompatibleWireStatus: HelperStatus?"
        ))
        let incompatibleLatch = try #require(sleepTransitionRestore.range(
            of: "if let incompatibleStatus = sleepTerminationIncompatibleWireStatus"
        ))
        let helperDispatch = try #require(sleepTransitionRestore.range(
            of: "let reply: HelperReply"
        ))
        #expect(incompatibleLatch.lowerBound < helperDispatch.lowerBound)
        #expect(sleepTransitionRestore.contains(
            "sleepTerminationIncompatibleWireStatus = reply.status"
        ))
        #expect(restoreMonitor.contains("case .manualRecoveryRequired:"))
        #expect(restoreMonitor.contains(
            "guard armRequestsInFlight == 0 else"
        ))
        #expect(client.contains("private var installStateEpoch: UInt64 = 0"))
        #expect(client.contains("func recordRecoveryOnlyStatus("))
        #expect(client.contains("guard epoch == installStateEpoch else { return }"))

        #expect(setup.contains("requires a reviewed removal procedure"))
        #expect(setup.contains("Public cleanup and replacement are disabled"))
        #expect(!setup.contains("Replace Helper…"))
        #expect(setup.contains("if let error = state.lastError"))
        #expect(onboarding.contains("Helper revision does not match"))
        #expect(onboarding.contains("does not have a public cleanup path"))
        #expect(!onboarding.contains("Replace Helper…"))
        #expect(onboarding.contains("No public replacement"))
        #expect(client.contains(
            "case stale(helperVersion: Int, helperSafetyRevision: Int?)"
        ))
        #expect(setup.contains("Emergency sleep recovery"))
        #expect(setup.contains("Text(\"Emergency sleep recovery\")"))
        #expect(!setup.contains("Manual fallback"))
        #expect(!setup.contains("one command undoes everything"))
        #expect(onboarding.contains("Emergency recovery"))
        #expect(onboarding.contains("Helper installed and responding"))
        #expect(!onboarding.contains("Helper installed and verified"))
        #expect(client.contains("separately reviewed"))
        #expect(setup.contains("reviewed procedure"))
        #expect(onboarding.contains("reviewed procedure"))
        #expect(architecture.contains("must stay registered"))
        #expect(!client.contains("matching Lidless version"))
        #expect(!setup.contains("matching Lidless version"))
        #expect(!onboarding.contains("matching Lidless version"))
        #expect(!architecture.contains("matching Lidless version"))
        #expect(!app.contains("matching-version removal"))
        #expect(!client.contains("before manual replacement"))
        #expect(!client.contains("before manually replacing or removing"))
        #expect(!setup.contains("every code path it has"))
        #expect(onboarding.contains("Recovery requires proof"))
        #expect(onboarding.contains("reports recovery only after current registry evidence verifies it"))
        #expect(!onboarding.contains("Never stranded"))
        #expect(!onboarding.contains("can't outlive Lidless"))
        #expect(!onboarding.contains("Every failure path restores"))
        #expect(!onboarding.contains("normal sleep first, always"))
        #expect(!onboarding.contains("restore within seconds"))
        #expect(!onboarding.contains("a reboot also cleans up"))
        #expect(client.contains(
            "case .notRegistered:\n            installState = .notInstalled"
        ))
        #expect(client.contains(
            "case .notFound:\n            installState = .unknown"
        ))
        #expect(!client.contains("case .notRegistered, .notFound:"))
        #expect(client.contains("Do not retry installation"))
        #expect(architecture.contains("Only explicit `.notRegistered`"))
        #expect(setup.contains("case .unknown: \"Helper status unverified\""))
        #expect(setup.contains("case .unknown:\n            Button(\"Re-check\")"))
        #expect(!setup.contains("case .unknown: \"Checking…\""))
        #expect(!setup.contains("case .unknown:\n            ProgressView()"))
        #expect(onboarding.contains("case .unknown: \"Helper status is unverified\""))
        #expect(onboarding.contains(
            "case .stale, .notResponding, .unknown: \"exclamationmark.triangle.fill\""
        ))
        // A concluded `.unknown` verdict must never be dressed as progress.
        // The pre-classification `.checking` state legitimately shows a
        // spinner, so this negative is scoped to the `.unknown` block itself.
        let onboardingUnknownCase = try section(
            of: onboarding,
            from: "case .unknown:",
            through: "case .checking:"
        )
        #expect(!onboardingUnknownCase.contains("ProgressView("))
        #expect(!onboardingUnknownCase.contains("Checking helper…"))
        #expect(setup.contains("classification is unavailable"))
        #expect(onboarding.contains("will not assume the helper is absent or safe to replace"))
    }
}
