import Foundation
import Testing
@testable import LidlessCore

@Suite("Helper daemon source safety")
struct HelperDaemonSourceSafetyTests {
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
        guard let startRange = source.range(of: start),
              let endRange = source.range(of: end, range: startRange.upperBound..<source.endIndex) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return source[startRange.lowerBound..<endRange.upperBound]
    }

    @Test func activeSessionPathsNeverRewriteTheRecoverySentinel() throws {
        let source = try repositoryFile("Helper/HelperDaemon.swift")
        let rearm = try section(
            of: source,
            from: "if var current = sentinel {",
            through: "// Snapshot optional settings"
        )
        let verifiedArm = try section(
            of: source,
            from: "let armReadback = PMSet.readSleepDisabled()",
            through: "// Best-effort extras"
        )
        let heartbeat = try section(
            of: source,
            from: "fileprivate func handleHeartbeat",
            through: "fileprivate func handleDisarm"
        )

        #expect(!rearm.contains("writeSentinel"))
        #expect(!verifiedArm.contains("writeSentinel"))
        #expect(!heartbeat.contains("writeSentinel"))
    }

    @Test func blockingCommandBoundsAreWiredIntoPMSet() throws {
        let source = try repositoryFile("Helper/PMSet.swift")

        #expect(source.contains("HelperSupervisionTiming.pmsetCommandTimeout"))
        #expect(source.contains("HelperSupervisionTiming.forcedTerminationGrace"))
        #expect(source.contains("let killResult = kill"))
        #expect(source.contains("killResult == 0 || killErrno == ESRCH"))
        #expect(!source.contains("timeout: TimeInterval = 20"))
    }

    @Test func supervisionPrecedesEnableAndSuccessPrecedesOptionalWork() throws {
        let source = try repositoryFile("Helper/HelperDaemon.swift")
        let freshArm = try section(
            of: source,
            from: "// Fresh arm.",
            through: "// Best-effort extras"
        )

        let sentinelWrite = try #require(freshArm.range(of: "try writeSentinel(record)"))
        let afterSentinelWrite = freshArm[sentinelWrite.upperBound...]
        let ownershipConfirmation = try #require(afterSentinelWrite.range(
            of: "SleepOverrideSafety.preflight(observed: PMSet.readSleepDisabled())"
        ))
        let memoryOwner = try #require(freshArm.range(of: "sentinel = record"))
        let enable = try #require(freshArm.range(of: "try PMSet.setSleepDisabled(true)"))
        let proof = try #require(freshArm.range(of: "SleepOverrideSafety.isArmProven(result)"))
        let successReply = try #require(freshArm.range(of: "reply(IPCCoding.encode(result))"))

        #expect(sentinelWrite.lowerBound < memoryOwner.lowerBound)
        #expect(ownershipConfirmation.lowerBound < memoryOwner.lowerBound)
        #expect(memoryOwner.lowerBound < enable.lowerBound)
        #expect(enable.lowerBound < proof.lowerBound)
        #expect(proof.lowerBound < successReply.lowerBound)
    }

    @Test func wakeSchedulingCannotBlockActiveSupervision() throws {
        let source = try repositoryFile("Helper/HelperDaemon.swift")
        let schedule = try section(
            of: source,
            from: "fileprivate func handleScheduleWake",
            through: "fileprivate func handleUninstall"
        )
        let guardPosition = try #require(schedule.range(
            of: "guard sentinel == nil, restorePending == nil"
        ))
        let commandPosition = try #require(schedule.range(of: "PMSet.scheduleWake"))

        #expect(guardPosition.lowerBound < commandPosition.lowerBound)
    }

    @Test func recoverySentinelStorageIsDescriptorBoundAndFailClosed() throws {
        let source = try repositoryFile("Helper/HelperDaemon.swift")
        let launchd = try repositoryFile(
            "Helper/Resources/com.lidless.helper.plist"
        )
        let startup = try section(
            of: source,
            from: "queue.sync { [self] in",
            through: "// Identity validation"
        )
        let recovery = try section(
            of: source,
            from: "private func recoveryPass",
            through: "private func installSignalHandlers"
        )
        let storage = try section(
            of: source,
            from: "private func ensureSecureWorkDirectory",
            through: "fileprivate func handleArm"
        )
        let directoryOpen = try section(
            of: String(storage),
            from: "private func openSecureWorkDirectory",
            through: "private func fullySynchronize"
        )
        let fullSync = try section(
            of: String(storage),
            from: "private func fullySynchronize",
            through: "private func closeStorageDescriptor"
        )
        let checkedClose = try section(
            of: String(storage),
            from: "private func closeStorageDescriptor",
            through: "private func storageMetadata"
        )
        let metadata = try section(
            of: String(storage),
            from: "private func storageMetadata",
            through: "private func readTrustedSentinel"
        )
        let read = try section(
            of: String(storage),
            from: "private func readTrustedSentinel",
            through: "private func readSentinelData"
        )
        let readData = try section(
            of: String(storage),
            from: "private func readSentinelData",
            through: "private func writeSentinel"
        )
        let write = try section(
            of: String(storage),
            from: "private func writeSentinel",
            through: "private func removeSentinelFile"
        )
        let removal = try section(
            of: String(storage),
            from: "private func removeSentinelFile",
            through: "private func reconcileSentinelPersistenceFailure"
        )
        let freshArm = try section(
            of: source,
            from: "// Fresh arm.",
            through: "// The sentinel write can block without end"
        )
        let repair = try section(
            of: source,
            from: "fileprivate func handleRepairOverride",
            through: "fileprivate func handleScheduleWake"
        )

        let directoryProof = try #require(startup.range(
            of: "try ensureSecureWorkDirectory()"
        ))
        let recoveryPass = try #require(startup.range(of: "recoveryPass("))
        #expect(directoryProof.lowerBound < recoveryPass.lowerBound)

        #expect(HelperPaths.workDirectoryParent == "/var/db")
        #expect(HelperPaths.workDirectoryName == "lidless")
        #expect(HelperPaths.workDirectory == "/var/db/lidless")
        #expect(HelperPaths.sentinelFilename == "override-active")
        #expect(HelperPaths.sentinel == "/var/db/lidless/override-active")
        let launchdPropertyList = try #require(
            PropertyListSerialization.propertyList(
                from: Data(launchd.utf8),
                options: [],
                format: nil
            ) as? [String: Any]
        )
        let keepAlive = try #require(
            launchdPropertyList["KeepAlive"] as? [String: Any]
        )
        let pathState = try #require(
            keepAlive["PathState"] as? [String: Bool]
        )
        #expect(pathState == [HelperPaths.sentinel: true])
        #expect(source.contains("HelperPaths.sentinelFilename"))
        #expect(!source.contains("private static let sentinelFilename"))

        // Parent proof precedes descriptor-relative creation/open. Every
        // accepted child—new or existing—is metadata-proven and both child
        // and parent namespaces receive a full persistence barrier.
        let parentOpen = try #require(directoryOpen.range(
            of: "var parentDescriptor = open("
        ))
        let parentProof = try #require(directoryOpen.range(
            of: "HelperStorageSafety.isSecureStorageDirectory(parentMetadata)"
        ))
        let directoryCreate = try #require(directoryOpen.range(of: "mkdirat("))
        let directoryDescriptorOpen = try #require(
            directoryOpen.range(of: "var directoryDescriptor = openat(")
        )
        let metadataProof = try #require(directoryOpen.range(
            of: "HelperStorageSafety.isSecureWorkDirectory(metadata)"
        ))
        let directorySync = try #require(directoryOpen.range(
            of: "try fullySynchronize(\n            directoryDescriptor"
        ))
        let parentSync = try #require(directoryOpen.range(
            of: "try fullySynchronize(\n            parentDescriptor"
        ))
        let parentClose = try #require(directoryOpen.range(
            of: "try closeStorageDescriptor(\n            &parentDescriptor"
        ))
        #expect(parentOpen.lowerBound < parentProof.lowerBound)
        #expect(parentProof.lowerBound < directoryCreate.lowerBound)
        #expect(directoryCreate.lowerBound < directoryDescriptorOpen.lowerBound)
        #expect(directoryDescriptorOpen.lowerBound < metadataProof.lowerBound)
        #expect(metadataProof.lowerBound < directorySync.lowerBound)
        #expect(directorySync.lowerBound < parentSync.lowerBound)
        #expect(parentSync.lowerBound < parentClose.lowerBound)

        #expect(fullSync.contains("fcntl(descriptor, F_FULLFSYNC)"))
        #expect(fullSync.contains("syncErrno == EINTR"))
        #expect(fullSync.contains(
            "throw StorageError(operation: operation, code: syncErrno)"
        ))
        let closeCall = try #require(checkedClose.range(
            of: "Darwin.close(descriptor)"
        ))
        let closeErrno = try #require(checkedClose.range(of: "let closeErrno = errno"))
        let invalidateDescriptor = try #require(checkedClose.range(
            of: "descriptor = -1"
        ))
        let closeProof = try #require(checkedClose.range(of: "closeResult == 0"))
        let closeFailure = try #require(checkedClose.range(
            of: "throw StorageError(operation: operation, code: closeErrno)"
        ))
        #expect(closeCall.lowerBound < closeErrno.lowerBound)
        #expect(closeErrno.lowerBound < invalidateDescriptor.lowerBound)
        #expect(invalidateDescriptor.lowerBound < closeProof.lowerBound)
        #expect(closeProof.lowerBound < closeFailure.lowerBound)
        #expect(metadata.contains("fstat(descriptor"))
        #expect(metadata.contains("acl_get_fd_np(descriptor, ACL_TYPE_EXTENDED)"))

        // Recovery reads only a descriptor-bound, nonblocking/no-follow,
        // metadata-proven regular file and decodes only those trusted bytes.
        #expect(recovery.contains("readTrustedSentinel"))
        #expect(!recovery.contains("Data(contentsOf:"))
        #expect(read.contains("O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC"))
        let readMetadataProof = try #require(read.range(
            of: "HelperStorageSafety.isTrustedSentinel("
        ))
        let descriptorRead = try #require(read.range(
            of: "readSentinelData(from: fileDescriptor)"
        ))
        let decode = try #require(read.range(of: "IPCCoding.decode("))
        #expect(readMetadataProof.lowerBound < descriptorRead.lowerBound)
        #expect(descriptorRead.lowerBound < decode.lowerBound)
        #expect(!read.contains("Data(contentsOf:"))
        for requiredReadBound in [
            "Darwin.read(fileDescriptor",
            "readErrno == EINTR",
            "Self.maximumSentinelBytes - count",
            "result.append(contentsOf: buffer.prefix(count))"
        ] {
            #expect(readData.contains(requiredReadBound))
        }

        // Creation is exclusive/no-follow and fully checked before its bytes,
        // file barrier, final metadata proof, checked close, directory
        // barrier, and checked directory close complete in that order.
        #expect(write.contains("O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC"))
        let owner = try #require(write.range(of: "fchown(fileDescriptor"))
        let mode = try #require(write.range(of: "fchmod(fileDescriptor"))
        let initialMetadata = try #require(write.range(
            of: "let initialSentinelMetadata"
        ))
        let dataWrite = try #require(write.range(of: "data.withUnsafeBytes"))
        let partialWriteLoop = try #require(write.range(
            of: "while offset < bytes.count"
        ))
        let descriptorWrite = try #require(write.range(
            of: "Darwin.write("
        ))
        let interruptedWriteRetry = try #require(write.range(
            of: "writeErrno == EINTR"
        ))
        let progressProof = try #require(write.range(of: "byteCount > 0"))
        let offsetAdvance = try #require(write.range(of: "offset += byteCount"))
        let fileSync = try #require(write.range(
            of: "try fullySynchronize(\n            fileDescriptor"
        ))
        let finalMetadata = try #require(write.range(
            of: "let finalSentinelMetadata"
        ))
        let fileClose = try #require(write.range(
            of: "try closeStorageDescriptor(\n            &fileDescriptor"
        ))
        let entrySync = try #require(write.range(
            of: "try fullySynchronize(\n            directoryDescriptor"
        ))
        let directoryClose = try #require(write.range(
            of: "try closeStorageDescriptor(\n            &directoryDescriptor"
        ))
        #expect(owner.lowerBound < mode.lowerBound)
        #expect(mode.lowerBound < initialMetadata.lowerBound)
        #expect(initialMetadata.lowerBound < dataWrite.lowerBound)
        #expect(dataWrite.lowerBound < partialWriteLoop.lowerBound)
        #expect(partialWriteLoop.lowerBound < descriptorWrite.lowerBound)
        #expect(descriptorWrite.lowerBound < interruptedWriteRetry.lowerBound)
        #expect(interruptedWriteRetry.lowerBound < progressProof.lowerBound)
        #expect(progressProof.lowerBound < offsetAdvance.lowerBound)
        #expect(offsetAdvance.lowerBound < fileSync.lowerBound)
        #expect(fileSync.lowerBound < finalMetadata.lowerBound)
        #expect(finalMetadata.lowerBound < fileClose.lowerBound)
        #expect(fileClose.lowerBound < entrySync.lowerBound)
        #expect(entrySync.lowerBound < directoryClose.lowerBound)

        let unlink = try #require(removal.range(of: "unlinkat("))
        let removalSync = try #require(removal.range(of: "try fullySynchronize("))
        let removalClose = try #require(removal.range(
            of: "try closeStorageDescriptor("
        ))
        #expect(unlink.lowerBound < removalSync.lowerBound)
        #expect(removalSync.lowerBound < removalClose.lowerBound)

        // The one definition and both persistence callers (fresh arm and
        // outside-override repair) must immediately reconcile any marker that
        // may have escaped a failed write/full-sync/close operation.
        let persistenceReconciliations = source.components(
            separatedBy: "reconcileSentinelPersistenceFailure("
        ).count - 1
        #expect(persistenceReconciliations == 3)
        let freshWrite = try #require(freshArm.range(of: "try writeSentinel(record)"))
        let freshReconcile = try #require(freshArm.range(
            of: "reconcileSentinelPersistenceFailure("
        ))
        let repairWrite = try #require(repair.range(of: "try writeSentinel(record)"))
        let repairReconcile = try #require(repair.range(
            of: "reconcileSentinelPersistenceFailure("
        ))
        #expect(freshWrite.lowerBound < freshReconcile.lowerBound)
        #expect(repairWrite.lowerBound < repairReconcile.lowerBound)
        #expect(recovery.contains("recoverUntrustedSentinel"))

        #expect(!source.contains("try? FileManager.default.setAttributes"))
        #expect(!source.contains("try? FileManager.default.createDirectory"))
    }
}
