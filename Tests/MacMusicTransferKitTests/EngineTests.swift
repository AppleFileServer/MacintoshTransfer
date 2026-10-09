import CryptoKit
import Foundation
import Testing
@testable import MacMusicTransferKit

/// The packaging engine (§7; V4-V8).
@Suite struct EngineTests {
    let f: Fixtures
    init() throws { f = try Fixtures() }

    func out() throws -> URL {
        let o = f.url("out")
        try FileManager.default.createDirectory(at: o, withIntermediateDirectories: true)
        return o
    }

    func queue(_ n: Int, seconds: Double = 1) throws -> Queue {
        var q = Queue()
        q.add(try (1...n).map { try f.wav("Song \($0).wav", seconds: seconds, seed: $0) })
        return q
    }

    @Test func twelveFilesVerifiedThreeWays() async throws {
        let q = try queue(12, seconds: 2)
        let before = try q.files.map { try Data(contentsOf: $0.source) }
        let steps = Steps()
        let r = try await TransferEngine().run(TransferJob(queue: q, folder: try out())) { steps.add($0) }
        #expect(r.image.lastPathComponent == "HD60_512 Transfer.hda")
        #expect(r.files.count == 12 && r.checks.contains { $0.contains("exactly the 12 files") })
        // The stages in order; copying counted file by file.
        #expect(steps.stages == [.checking, .preparing, .formatting, .copying, .verifying, .finishing])
        #expect(steps.list.filter { $0.stage == .copying }.count == 12)
        // Independently again, after the move.
        let reader = try HFSReader(r.image)
        let folder = reader.contents(of: HFSReader.rootID).first { $0.isFolder }!
        #expect(reader.contents(of: folder.id).count == 12)
        #expect(try q.files.map { try Data(contentsOf: $0.source) } == before)
        #expect(try FileManager.default.contentsOfDirectory(atPath: try out().path) == ["HD60_512 Transfer.hda"])
        #expect(r.summary.contains("SHA-256"))
    }

    @Test func otherIDs() async throws {
        let r = try await TransferEngine().run(TransferJob(queue: try queue(1), folder: try out(), scsiID: 2))
        #expect(r.image.lastPathComponent == "HD20_512 Transfer.hda")
        await #expect(throws: TransferError.badID(7)) {
            try await TransferEngine().run(TransferJob(queue: try queue(1), folder: try out(), scsiID: 7))
        }
    }

    @Test func refusals() async throws {
        await #expect(throws: TransferError.emptyQueue) {
            try await TransferEngine().run(TransferJob(queue: Queue(), folder: try out()))
        }
        var bad = try queue(1)
        bad.add([try f.anyWAV("stereo.wav", channels: 2)])
        await #expect(throws: TransferError.refusedFiles(["stereo.wav"])) {
            try await TransferEngine().run(TransferJob(queue: bad, folder: try out()))
        }
        await #expect(throws: TransferError.self) {
            try await TransferEngine().run(TransferJob(queue: try queue(1), folder: f.url("no-such-folder")))
        }
    }

    /// An image already there (V5): refused, replaced, or kept with the new
    /// one beside it; the finished one never harmed unasked.
    @Test func anExistingImage() async throws {
        let o = try out()
        let first = try await TransferEngine().run(TransferJob(queue: try queue(1), folder: o))
        let original = try Data(contentsOf: first.image)
        await #expect(throws: TransferError.imageExists(first.image.path)) {
            try await TransferEngine().run(TransferJob(queue: try queue(2), folder: o))
        }
        #expect(try Data(contentsOf: first.image) == original)
        let both = try await TransferEngine().run(TransferJob(queue: try queue(2), folder: o, existing: .keepBoth))
        #expect(both.image.lastPathComponent == "HD60_512 Transfer 2.hda")
        #expect(BlueSCSI.parse(both.image.lastPathComponent)! == (6, 0, 512))
        #expect(both.warnings.contains { $0.contains("second image for ID 6") })
        #expect(try Data(contentsOf: first.image) == original)
        let replaced = try await TransferEngine().run(TransferJob(queue: try queue(3), folder: o, existing: .replace))
        #expect(replaced.image == first.image && replaced.files.count == 3)
    }

    /// Cancelling at each stage leaves nothing behind but the sources (V4).
    @Test(arguments: [TransferProgress.Stage.preparing, .formatting, .copying, .verifying])
    func cancellingLeavesNothing(at stage: TransferProgress.Stage) async throws {
        let o = try out()
        let q = try queue(4, seconds: 1)
        let job = Task { () async throws -> TransferResult in
            try await TransferEngine().run(TransferJob(queue: q, folder: o)) { p in
                if p.stage == stage { withUnsafeCurrentTask { $0?.cancel() } }
            }
        }
        await #expect(throws: TransferError.cancelled) { try await job.value }
        #expect(try FileManager.default.contentsOfDirectory(atPath: o.path).isEmpty)
        #expect(q.files.allSatisfy { FileManager.default.fileExists(atPath: $0.source.path) })
    }

    /// A source changed after it was added is caught, not packaged.
    @Test func aChangedSource() async throws {
        let q = try queue(2)
        try Data("changed".utf8).write(to: q.files[0].source)
        await #expect(throws: TransferError.sourceChanged(q.files[0].source.lastPathComponent)) {
            try await TransferEngine().run(TransferJob(queue: q, folder: try out()))
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: try out().path).isEmpty)
    }

    /// A template that isn't one: refused before anything is made.
    @Test func aBadTemplate() async throws {
        let junk = f.url("junk.hda")
        try Data(repeating: 1, count: 96 * 512).write(to: junk)
        await #expect(throws: TransferError.self) {
            try await TransferEngine().run(TransferJob(queue: try queue(1), folder: try out(), template: junk))
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: try out().path).isEmpty)
    }

    @Test func sizeExplained() throws {
        let job = TransferJob(queue: try queue(2, seconds: 10), folder: f.folder)
        #expect(job.sizeExplanation.contains("plus 25%") && job.sizeExplanation.hasSuffix("10 MB."))
    }

    /// Names that had to change arrive under their Mac names.
    @Test func renamedFilesArriveRenamed() async throws {
        var q = Queue()
        q.add([try f.wav("Chill Dreamy Lounge by unfeel No Copyright.wav", seconds: 1),
               try f.wav("Москва: Live.wav", seconds: 1, seed: 2)])
        let r = try await TransferEngine().run(TransferJob(queue: q, folder: try out()))
        let reader = try HFSReader(r.image)
        let folder = reader.contents(of: HFSReader.rootID).first { $0.isFolder }!
        #expect(Set(reader.contents(of: folder.id).map(\.name)) == Set(q.files.map(\.macName)))
        #expect(q.files.allSatisfy { $0.macName.count <= 31 })
    }
}

final class Steps: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [TransferProgress] = []
    func add(_ p: TransferProgress) { lock.withLock { items.append(p) } }
    var list: [TransferProgress] { lock.withLock { items } }
    var stages: [TransferProgress.Stage] {
        list.map(\.stage).reduce(into: []) { if $0.last != $1 { $0.append($1) } }
    }
}
