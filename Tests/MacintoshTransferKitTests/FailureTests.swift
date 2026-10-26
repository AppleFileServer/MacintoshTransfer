import Foundation
import Testing
@testable import MacintoshTransferKit

/// Failures mid-build (Stage 4; L2, L3): a plain error, no image left
/// behind (not even a hidden part-made one), the sources untouched.
@Suite struct FailureTests {
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

    func nothingLeft(_ folder: URL) throws -> Bool {
        try FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty
    }

    /// hfsutils failing part-way: a stand-in hcopy that fails on the third
    /// file (the others are the real tools).
    @Test func hfsutilsFailingPartWay() async throws {
        let fake = f.url("fake-hfsutils")
        try FileManager.default.createDirectory(at: fake, withIntermediateDirectories: true)
        for tool in HFSUtils.needed where tool != "hcopy" {
            try FileManager.default.createSymbolicLink(at: fake.appendingPathComponent(tool),
                                                       withDestinationURL: HFSUtils.developmentFolder.appendingPathComponent(tool))
        }
        let count = f.url("hcopy-count")
        let script = """
            #!/bin/sh
            n=$(cat '\(count.path)' 2>/dev/null || echo 0); n=$((n + 1)); echo $n > '\(count.path)'
            if [ $n -ge 3 ]; then echo "hcopy: simulated failure" >&2; exit 1; fi
            exec '\(HFSUtils.developmentFolder.appendingPathComponent("hcopy").path)' "$@"
            """
        try script.write(to: fake.appendingPathComponent("hcopy"), atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fake.appendingPathComponent("hcopy").path)
        let q = try queue(5)
        let o = try out()
        do {
            _ = try await TransferEngine(hfsHelpers: fake).run(TransferJob(queue: q, folder: o))
            Issue.record("it didn't fail")
        } catch let e as TransferError {
            #expect(e.message.contains("simulated failure"), "\(e.message)")
        }
        #expect(try nothingLeft(o))
        #expect(q.files.allSatisfy { FileManager.default.fileExists(atPath: $0.source.path) })
    }

    @Test func anUnreadableSource() async throws {
        var q = Queue()
        let locked = try f.wav("locked.wav", seconds: 1)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: locked.path) }
        q.add([locked])
        #expect(q.files.first?.problem != nil)                          // refused when added
        // Readable when added, then locked: caught at the build.
        let q2 = try queue(2)
        let later = q2.files[1].source
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: later.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: later.path) }
        let o = try out()
        await #expect(throws: TransferError.self) { try await TransferEngine().run(TransferJob(queue: q2, folder: o)) }
        #expect(try nothingLeft(o))
        #expect(q2.files.allSatisfy { FileManager.default.fileExists(atPath: $0.source.path) })
    }

    @Test func theFolderRemovedMidBuild() async throws {
        let q = try queue(4)
        let o = try out()
        await #expect(throws: (any Error).self) {
            try await TransferEngine().run(TransferJob(queue: q, folder: o)) { p in
                if p.stage == .copying { try? FileManager.default.removeItem(at: o) }
            }
        }
        #expect(!FileManager.default.fileExists(atPath: o.path))
        #expect(q.files.allSatisfy { FileManager.default.fileExists(atPath: $0.source.path) })
    }

    /// A small disk (4 MB, made with hdiutil): refused up front; and, the
    /// check skipped, filling mid-write: an error, and nothing left.
    @Test(.enabled(if: FileManager.default.isExecutableFile(atPath: "/usr/bin/hdiutil")))
    func aFullDisk() async throws {
        let image = f.url("small.dmg"), mount = f.url("small")
        let hdiutil = URL(fileURLWithPath: "/usr/bin/hdiutil")
        let made = try await ProcessRunner().run(hdiutil, arguments: [
            "create", "-size", "4m", "-fs", "HFS+", "-volname", "mtu-small", "-quiet", image.path])
        try #require(made.status == 0, "\(made.stderrText)")
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        let attached = try await ProcessRunner().run(hdiutil, arguments: [
            "attach", "-nobrowse", "-noverify", "-mountpoint", mount.path, "-quiet", image.path])
        try #require(attached.status == 0, "\(attached.stderrText)")
        defer {
            let p = Process()
            p.executableURL = hdiutil
            p.arguments = ["detach", "-force", "-quiet", mount.path]
            try? p.run()
            while p.isRunning { usleep(50_000) }
        }
        let q = try queue(3, seconds: 60)                              // 4 MB of files: a 10 MB disk
        do {
            _ = try await TransferEngine().run(TransferJob(queue: q, folder: mount))
            Issue.record("it was built on a 4 MB disk")
        } catch let e as TransferError {
            guard case .insufficientSpace = e else { Issue.record("\(e)"); return }
        }
        var reckless = TransferEngine()
        reckless.checksSpace = false
        await #expect(throws: (any Error).self) { try await reckless.run(TransferJob(queue: q, folder: mount)) }
        let left = try FileManager.default.contentsOfDirectory(atPath: mount.path)
        #expect(!left.contains { $0.hasSuffix(".hda") || $0.hasSuffix(".partial") }, "\(left)")
    }

    @Test func leftoversOursAndOldOnly() throws {
        let hourAgo = Date().addingTimeInterval(-3_700)
        func make(_ name: String, old: Bool) throws -> URL {
            let u = f.url(name)
            try Data("x".utf8).write(to: u)
            if old { try FileManager.default.setAttributes([.modificationDate: hourAgo], ofItemAtPath: u.path) }
            return u
        }
        let a = try make(".mtu-1.hda.partial", old: true), b = try make(".mtu-2.hda.partial", old: false)
        let c = try make("mtu-job-3", old: true), d = try make("HD60_512 Transfer.hda", old: true)
        let e = try make(".mmc-4.wav.partial", old: true)               // the Converter's: not ours
        let removed = Set(Leftovers.clean([f.folder]).map(\.lastPathComponent))
        #expect(removed == [a.lastPathComponent, c.lastPathComponent])
        for kept in [b, d, e] { #expect(FileManager.default.fileExists(atPath: kept.path)) }
    }
}
