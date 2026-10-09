import Foundation
import Testing
@testable import MacMusicTransferKit

/// Larger disks and many files (Stage 4; L1).
@Suite struct ScaleTests {
    let f: Fixtures
    init() throws { f = try Fixtures() }

    func out() throws -> URL {
        let o = f.url("out")
        try FileManager.default.createDirectory(at: o, withIntermediateDirectories: true)
        return o
    }

    /// MacMusic's limit: 500 songs. The catalog spans many nodes.
    @Test func fiveHundredFiles() async throws {
        var q = Queue()
        q.add(try (1...500).map { try f.wav("Track \($0).wav", seconds: 0.05, seed: $0) })
        let r = try await TransferEngine().run(TransferJob(queue: q, folder: try out()))
        #expect(r.files.count == 500 && r.checks.contains { $0.contains("exactly the 500 files") })
    }

    /// Over 32 MB, HFS uses allocation blocks larger than 512 bytes.
    @Test func aHundredMegabyteDisk() async throws {
        var q = Queue()
        q.add(try (1...4).map { try f.wav("Long \($0).wav", seconds: 900, seed: $0) })      // 4 x 19.8 MB
        let r = try await TransferEngine().run(TransferJob(queue: q, folder: try out()))
        let reader = try HFSReader(r.image)
        #expect(reader.allocationBlockSize > 512, "\(reader.allocationBlockSize)")
        #expect(r.imageBytes > 90 * 1_048_576 && r.checks.contains { $0.contains("exactly the 4 files") })
    }
}
