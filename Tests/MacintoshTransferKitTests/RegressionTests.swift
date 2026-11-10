import CryptoKit
import Foundation
import Testing
@testable import MacintoshTransferKit

/// A WAV-only image is still 1.0's (M10, K10): the same five WAVs built by
/// 2.0 give an image identical to the one 1.0 (`v1.0`, 0759ea0) built,
/// byte for byte apart from the dates hformat and hcopy stamp. The record
/// below was made by 1.0's own `mtu-build` (SPECIFICATION.md §15.10).
@Suite struct RegressionTests {
    let f: Fixtures
    init() throws { f = try Fixtures() }

    /// The five WAVs, in the order they were given to 1.0: an identical
    /// pair, an accented name with an odd-length audio chunk, and two long
    /// names cut to the same name, so the second is made unique.
    func theFiles() throws -> [URL] {
        [try f.wav("Song One.wav", seconds: 1, seed: 1),
         try f.wav("Song One copy.wav", seconds: 1, seed: 1),
         try f.wav("Café.wav", seconds: 0.5, seed: 2),
         try f.wav("A very long name for a song that won't fit 1.wav", seconds: 1, seed: 3),
         try f.wav("A very long name for a song that won't fit 2.wav", seconds: 1, seed: 4)]
    }

    /// What 1.0 made of them.
    static let v1 = Print(
        imageBytes: 10_485_760,
        headerSHA256: "e0213f3859eb4138a171760c91f7ddf69fcfe2b401a1fd5407bbdd8b8610ab7f",
        maskedSHA256: "588549917aa707eb5bbd7dabe5416bb701ed6f9b774bac706edc7eb7bbfd0b42",
        entries: [
            "1 2 Transfer/",
            "2 16 WAV Files/",
            "16 21 A very long name for a 2.wav WAVE ???? 22094 0 472+44 871ff6eecb3a867cccc5be216cb5def89c8ee5adca171a50fc7c9ca1e5c78525",
            "16 20 A very long name for a.wav WAVE ???? 22094 0 428+44 0059813345d2fdb94792864352215911442c69e48a81904d064f4466938fa000",
            "16 19 Café.wav WAVE ???? 11070 0 406+22 a2e79949c06fd1a77d7c4f421bf94baf5c364010251561239a8f5fa1c8c23965",
            "16 18 Song One copy.wav WAVE ???? 22094 0 362+44 f353c0b35cf095b2ce7a9f055408af72ec35eff1abca68052f947298b226f608",
            "16 17 Song One.wav WAVE ???? 22094 0 318+44 f353c0b35cf095b2ce7a9f055408af72ec35eff1abca68052f947298b226f608",
        ])

    @Test func aWAVOnlyImageIsStillOnePointZeros() async throws {
        let files = try theFiles()
        var q = Queue()
        q.add(files)
        let r = try await TransferEngine().run(TransferJob(queue: q, folder: f.folder))
        let print = try Print.of(r.image)
        #expect(print.entries == Self.v1.entries)
        #expect(print.imageBytes == Self.v1.imageBytes)
        #expect(print.headerSHA256 == Self.v1.headerSHA256)
        #expect(print.maskedSHA256 == Self.v1.maskedSHA256)
    }

    /// Two builds of the same files differ only in their dates, so the
    /// masking finds every date (or the comparison above couldn't hold).
    @Test func twoBuildsDifferOnlyInTheirDates() async throws {
        var q = Queue()
        q.add(try theFiles())
        let one = f.url("one"), two = f.url("two")
        for d in [one, two] { try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true) }
        let a = try await TransferEngine().run(TransferJob(queue: q, folder: one))
        try await Task.sleep(for: .seconds(1.1))                        // a different second
        let b = try await TransferEngine().run(TransferJob(queue: q, folder: two))
        #expect(try Data(contentsOf: a.image) != Data(contentsOf: b.image))
        #expect(try Print.of(a.image) == Print.of(b.image))
    }

    /// For recording `v1` again: `MTU_V1_IMAGE=<1.0's image> tools/test.sh
    /// --filter recordTheImage` prints its print.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["MTU_V1_IMAGE"] != nil))
    func recordTheImage() throws {
        let p = try Print.of(URL(fileURLWithPath: ProcessInfo.processInfo.environment["MTU_V1_IMAGE"]!))
        Swift.print("imageBytes: \(p.imageBytes),\nheaderSHA256: \"\(p.headerSHA256)\",\nmaskedSHA256: \"\(p.maskedSHA256)\",")
        Swift.print("entries: [\n" + p.entries.map { "    \"\($0)\"," }.joined(separator: "\n") + "]")
    }
}

/// An image's layout, without its dates: its size, its first 96 blocks,
/// the whole image with every HFS date zeroed, and (to say what differs)
/// every catalog entry.
struct Print: Equatable {
    let imageBytes: Int
    let headerSHA256: String
    let maskedSHA256: String
    let entries: [String]

    static func of(_ image: URL) throws -> Print {
        let reader = try HFSReader(image)
        let masked = try masked(image, reader)
        let entries = try reader.entries.map { e in
            let place = e.dataExtents.map { "\($0.start)+\($0.count)" }.joined(separator: ",")
            return e.isFolder ? "\(e.parent) \(e.id) \(e.name)/"
                : "\(e.parent) \(e.id) \(e.name) \(e.type) \(e.creator) \(e.dataLength) \(e.resourceLength) \(place) \(try reader.sha256(of: e))"
        }
        return Print(imageBytes: masked.count, headerSHA256: sha(masked.prefix(PartitionTemplate.bytes)),
                     maskedSHA256: sha(masked), entries: entries)
    }

    static func sha(_ d: Data) -> String { SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined() }

    /// The image with its dates zeroed (Inside Macintosh: Files): the
    /// volume's created, modified and backed-up dates in the Master
    /// Directory Block and its copy at the volume's end; each catalog
    /// folder's and file's created, modified and backed-up dates; and each
    /// catalog node's free space, where hfsutils leaves old copies of
    /// records it moved when splitting a node (dates among them).
    static func masked(_ image: URL, _ reader: HFSReader) throws -> Data {
        var d = try Data(contentsOf: image)
        func zero(_ at: Int) { d.replaceSubrange(at..<(at + 4), with: Data(count: 4)) }
        let p = reader.partitionOffset
        let mdb = d.subdata(in: (p + 1024)..<(p + 1536))
        for block in [p + 1024, p + reader.partitionLength - 1024] {
            for o in [2, 6, 64] { zero(block + o) }                     // drCrDate, drLsMod, drVolBkUp
        }
        // The catalog's 512-byte nodes, where they are in the image.
        var nodes: [Int] = []
        for e in HFSReader.extents(mdb, at: 150) {
            let start = reader.offset(ofAllocationBlock: e.start)
            nodes += (0..<(e.count * reader.allocationBlockSize / 512)).map { start + 512 * $0 }
        }
        for node in nodes.prefix(Int(mdb.uint32(at: 146)) / 512) {
            let count = Int(d.uint16(at: node + 10))
            let table = 512 - 2 * (count + 1)                           // the record offsets, at the node's end
            guard table > 14 else { continue }
            let free = Int(d.uint16(at: node + table))
            if free >= 14, free <= table { d.replaceSubrange((node + free)..<(node + table), with: Data(count: table - free)) }
            guard Int8(bitPattern: d[node + 8]) == -1 else { continue }  // a leaf: its records
            for i in 0..<count {
                let at = node + Int(d.uint16(at: node + 512 - 2 * (i + 1)))
                var rec = at + 1 + Int(d[at])
                if rec % 2 == 1 { rec += 1 }
                switch d[rec] {
                case 1: for o in [10, 14, 18] { zero(rec + o) }             // dirCrDat, dirMdDat, dirBkDat
                case 2: for o in [44, 48, 52] { zero(rec + o) }             // filCrDat, filMdDat, filBkDat
                default: break
                }
            }
        }
        return d
    }
}
