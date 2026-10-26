import CryptoKit
import Foundation
import Testing
@testable import MacintoshTransferKit

/// Stage 1, the proof: real images, made by hfsutils from the template,
/// checked three ways (§8; Q5).
@Suite struct ImageTests {
    let f: Fixtures
    init() throws { f = try Fixtures() }

    func make(_ files: [ImageFile], bytes: Int? = nil) async throws -> URL {
        let out = f.url("HD60_512 Transfer.hda")
        let total = try files.reduce(0) { $0 + (try Data(contentsOf: $1.source).count) }
        try await ImageBuilder(template: try f.template(), hfsutils: try f.hfsutils())
            .build(files, imageBytes: bytes ?? Sizing.imageBytes(forFiles: total), to: out)
        return out
    }

    func threeSongs() throws -> [ImageFile] {
        [ImageFile(source: try f.wav("one.wav", seconds: 2, seed: 1), macName: "Song One.wav"),
         ImageFile(source: try f.wav("two.wav", seconds: 3.3, seed: 2), macName: "Good Luck, Babe!.wav"),
         ImageFile(source: try f.wav("three.wav", seconds: 0.5, seed: 3), macName: "Café Song.wav")]
    }

    @Test func buildsAndVerifies() async throws {
        let files = try threeSongs()
        let image = try await make(files)
        let report = ImageVerifier.verify(image, files: files, template: try f.template())
        #expect(report.passed, "\(report.problems)")
        #expect(report.checks.contains { $0.contains("are the template's") })   // hformat left the map alone
    }

    @Test func theReaderSeesTheLayout() async throws {
        let files = try threeSongs()
        let r = try HFSReader(try await make(files))
        #expect(r.volumeName == "Transfer")
        #expect(r.allocationBlockSize == 512)                                 // a small volume
        let folder = try #require(r.contents(of: HFSReader.rootID).first { $0.isFolder })
        #expect(folder.name == "WAV Files")
        let names = r.contents(of: folder.id).map(\.name).sorted()
        #expect(names == ["Café Song.wav", "Good Luck, Babe!.wav", "Song One.wav"])
        #expect(r.contents(of: folder.id).allSatisfy { $0.type == "WAVE" && $0.creator == "????" && $0.resourceLength == 0 })
    }

    /// A third reader, written by someone else: machfs (MIT), from the
    /// tests' venv. Skipped when it isn't installed (BUILDING.md).
    @Test(.enabled(if: FileManager.default.isExecutableFile(atPath: Self.machfsPython)))
    func machfsAgrees() async throws {
        let files = try threeSongs()
        let image = try await make(files)
        let script = """
            import sys, hashlib, machfs
            data = open(sys.argv[1], 'rb').read()[96 * 512:]
            # machfs's read() doesn't keep the volume's name: read it from the
            # Master Directory Block (drVN, 36 bytes in) here.
            n = data[1024 + 36]
            print('volume', data[1024 + 37:1024 + 37 + n].decode('mac_roman'))
            v = machfs.Volume(); v.read(data)
            for name, f in sorted(v['WAV Files'].items()):
                print(name, f.type.decode('mac_roman'), len(f.rsrc), hashlib.sha256(f.data).hexdigest())
            """
        let r = try await ProcessRunner().run(URL(fileURLWithPath: Self.machfsPython),
                                              arguments: ["-c", script, image.path])
        #expect(r.status == 0, "\(r.stderrText)")
        let lines = r.stdoutText.split(separator: "\n").map(String.init)
        #expect(lines.first == "volume Transfer")
        for file in files {
            let sha = SHA256.hash(data: try Data(contentsOf: file.source)).map { String(format: "%02x", $0) }.joined()
            #expect(lines.contains("\(file.macName) WAVE 0 \(sha)"), "\(file.macName): \(lines)")
        }
    }

    static let machfsPython = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("MacPlusProjects/transfer-tools/venv/bin/python").path

    /// The verifier notices: a changed byte in a song; a file missing.
    @Test func verifierCatchesDifferences() async throws {
        let files = try threeSongs()
        let image = try await make(files)
        let r = try HFSReader(image)
        let folder = r.contents(of: HFSReader.rootID).first { $0.isFolder }!
        let song = r.contents(of: folder.id).first { $0.name == "Song One.wav" }!
        let at = r.offset(ofAllocationBlock: song.dataExtents[0].start) + 100
        let h = try FileHandle(forUpdating: image)
        try h.seek(toOffset: UInt64(at)); let old = try h.read(upToCount: 1)![0]
        try h.seek(toOffset: UInt64(at)); h.write(Data([old ^ 0xFF])); try h.close()
        let damaged = ImageVerifier.verify(image, files: files, template: try f.template())
        #expect(damaged.problems.contains { $0.contains("Song One.wav") && $0.contains("differs") })

        let fewer = ImageVerifier.verify(image, files: Array(files.dropLast()), template: try f.template())
        #expect(fewer.problems.contains { $0.contains("the folder holds") })
    }

    @Test func tooSmallIsRefusedBeforeCopying() async throws {
        let big = ImageFile(source: try f.wav("big.wav", seconds: 600), macName: "Big.wav")   // 13 MB
        await #expect(throws: ImageBuilder.Problem.self) { try await make([big], bytes: 10 * 1_048_576) }
    }

    /// hfsutils kept its state in the job's own HOME, not the user's.
    @Test func hfsutilsUsesAPrivateHome() async throws {
        _ = try await make(try threeSongs())
        #expect(FileManager.default.fileExists(atPath: f.url("hfs-home/.hcwd").path))
    }

    @Test func sourcesAreUnchanged() async throws {
        let files = try threeSongs()
        let before = try files.map { try Data(contentsOf: $0.source) }
        _ = try await make(files)
        #expect(try files.map { try Data(contentsOf: $0.source) } == before)
    }
}
