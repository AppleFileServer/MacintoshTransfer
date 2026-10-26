import CryptoKit
import Foundation

/// An HFS reader, written from Apple's documented format (Inside Macintosh:
/// Files, "Data Organization on Volumes") and sharing nothing with
/// hfsutils, so the image can be checked by something other than what made
/// it (decision Q5). Read-only; it handles what a fresh volume holds and
/// refuses, rather than guesses, anything else (files spread into the
/// extents-overflow file, B-tree nodes other than 512 bytes).
public struct HFSReader {
    public struct Entry: Sendable, Equatable {
        public let name: String
        public let isFolder: Bool
        public let id: UInt32
        public let parent: UInt32
        public let type: String
        public let creator: String
        public let dataLength: Int
        public let resourceLength: Int
        let dataExtents: [(start: Int, count: Int)]

        public static func == (a: Entry, b: Entry) -> Bool {
            a.name == b.name && a.isFolder == b.isFolder && a.id == b.id && a.parent == b.parent
                && a.type == b.type && a.creator == b.creator && a.dataLength == b.dataLength
                && a.resourceLength == b.resourceLength
        }
    }

    public enum Problem: Error, Equatable, Sendable {
        case unreadable(String)
        case noPartitionMap
        case noHFSPartition
        case notHFS(String)
        case unsupported(String)
        case damaged(String)
    }

    public let image: URL
    /// Where the HFS partition starts, in bytes, and its length.
    public let partitionOffset: Int
    public let partitionLength: Int
    public let volumeName: String
    public let allocationBlockSize: Int
    public let allocationBlocks: Int
    public let freeBlocks: Int
    let firstAllocationSector: Int
    public private(set) var entries: [Entry] = []

    public var freeBytes: Int { freeBlocks * allocationBlockSize }

    public static let rootID: UInt32 = 2

    public init(_ image: URL) throws {
        self.image = image
        let head = try Self.read(image, 0, 512 * 96)
        guard head.count >= 1024, head[0] == 0x45, head[1] == 0x52 else { throw Problem.noPartitionMap }
        var offset: Int?, length = 0
        for i in 1..<96 {
            let e = 512 * i
            guard head.count >= e + 512, head[e] == 0x50, head[e + 1] == 0x4D else { break }
            let type = PartitionTemplate.text(head, e + 48, 32)
            if type == "Apple_HFS" {
                offset = Int(head.uint32(at: e + 8)) * 512
                length = Int(head.uint32(at: e + 12)) * 512
                break
            }
        }
        guard let offset else { throw Problem.noHFSPartition }
        partitionOffset = offset
        partitionLength = length

        // The Master Directory Block, 1024 bytes into the volume.
        let mdb = try Self.read(image, offset + 1024, 512)
        guard mdb.count == 512, mdb.uint16(at: 0) == 0x4244 else {
            throw Problem.notHFS("no HFS volume signature (\"BD\") where the volume should begin")
        }
        allocationBlocks = Int(mdb.uint16(at: 18))
        allocationBlockSize = Int(mdb.uint32(at: 20))
        firstAllocationSector = Int(mdb.uint16(at: 28))
        freeBlocks = Int(mdb.uint16(at: 34))
        let nameLength = min(Int(mdb[36]), 27)
        volumeName = String(data: mdb.subdata(in: 37..<(37 + nameLength)), encoding: .macOSRoman) ?? ""
        guard allocationBlockSize > 0, allocationBlockSize % 512 == 0 else {
            throw Problem.damaged("an allocation block size of \(allocationBlockSize)")
        }
        let catalogSize = Int(mdb.uint32(at: 146))
        let catalogExtents = Self.extents(mdb, at: 150)
        guard catalogExtents.reduce(0, { $0 + $1.count }) * allocationBlockSize >= catalogSize else {
            throw Problem.unsupported("the catalog continues in the extents-overflow file")
        }
        entries = try readCatalog(extents: catalogExtents, size: catalogSize)
    }

    static func read(_ url: URL, _ offset: Int, _ count: Int) throws -> Data {
        do {
            let h = try FileHandle(forReadingFrom: url)
            defer { try? h.close() }
            try h.seek(toOffset: UInt64(offset))
            return try h.read(upToCount: count) ?? Data()
        } catch {
            throw Problem.unreadable(error.localizedDescription)
        }
    }

    static func extents(_ d: Data, at o: Int) -> [(start: Int, count: Int)] {
        (0..<3).map { (Int(d.uint16(at: o + 4 * $0)), Int(d.uint16(at: o + 4 * $0 + 2))) }.filter { $0.1 > 0 }
    }

    /// Where an allocation block starts, in the image.
    func offset(ofAllocationBlock n: Int) -> Int {
        partitionOffset + firstAllocationSector * 512 + n * allocationBlockSize
    }

    /// Reads `length` bytes of a fork from its extents.
    func readFork(_ extents: [(start: Int, count: Int)], length: Int) throws -> Data {
        var out = Data()
        for e in extents where out.count < length {
            let want = min(e.count * allocationBlockSize, length - out.count)
            out.append(try Self.read(image, offset(ofAllocationBlock: e.start), want))
        }
        guard out.count == length else { throw Problem.damaged("a fork is shorter than its length") }
        return out
    }

    /// Walks the catalog B-tree's leaf nodes, from the first leaf along
    /// their forward links.
    func readCatalog(extents: [(start: Int, count: Int)], size: Int) throws -> [Entry] {
        let catalog = try readFork(extents, length: size)
        let nodeSize = Int(catalog.uint16(at: 14 + 18))
        guard nodeSize == 512 else { throw Problem.unsupported("catalog nodes of \(nodeSize) bytes") }
        guard catalog[8] == 1 else { throw Problem.damaged("the catalog's first node isn't its header") }
        var node = Int(catalog.uint32(at: 14 + 10))                     // bthFNode
        var found: [Entry] = []
        var seen = Set<Int>()
        while node != 0 {
            guard !seen.contains(node), (node + 1) * nodeSize <= catalog.count else {
                throw Problem.damaged("the catalog's leaf chain is broken")
            }
            seen.insert(node)
            let n = catalog.subdata(in: (node * nodeSize)..<((node + 1) * nodeSize))
            guard Int8(bitPattern: n[8]) == -1 else { throw Problem.damaged("a leaf link leads to a non-leaf node") }
            let records = Int(n.uint16(at: 10))
            for r in 0..<records {
                let at = Int(n.uint16(at: nodeSize - 2 * (r + 1)))
                if let e = try entry(n, at) { found.append(e) }
            }
            node = Int(n.uint32(at: 0))                                 // ndFLink
        }
        return found
    }

    /// One catalog record: folders and files (threads are skipped).
    func entry(_ n: Data, _ at: Int) throws -> Entry? {
        let keyLength = Int(n[at])
        let parent = n.uint32(at: at + 2)
        let nameLength = Int(n[at + 6])
        let name = String(data: n.subdata(in: (at + 7)..<(at + 7 + nameLength)), encoding: .macOSRoman) ?? ""
        var d = at + 1 + keyLength
        if d % 2 == 1 { d += 1 }
        switch n[d] {
        case 1:                                                         // a folder
            return Entry(name: name, isFolder: true, id: n.uint32(at: d + 6), parent: parent,
                         type: "", creator: "", dataLength: 0, resourceLength: 0, dataExtents: [])
        case 2:                                                         // a file
            let type = String(data: n.subdata(in: (d + 4)..<(d + 8)), encoding: .macOSRoman) ?? ""
            let creator = String(data: n.subdata(in: (d + 8)..<(d + 12)), encoding: .macOSRoman) ?? ""
            let dataLength = Int(n.uint32(at: d + 26))
            let resourceLength = Int(n.uint32(at: d + 36))
            let ext = Self.extents(n, at: d + 74)
            guard ext.reduce(0, { $0 + $1.count }) * allocationBlockSize >= dataLength else {
                throw Problem.unsupported("\"\(name)\" continues in the extents-overflow file")
            }
            return Entry(name: name, isFolder: false, id: n.uint32(at: d + 20), parent: parent,
                         type: type, creator: creator, dataLength: dataLength, resourceLength: resourceLength,
                         dataExtents: ext)
        default:
            return nil
        }
    }

    /// The entries in a folder.
    public func contents(of folder: UInt32) -> [Entry] { entries.filter { $0.parent == folder } }

    /// A file's data fork's SHA-256.
    public func sha256(of e: Entry) throws -> String {
        let data = try readFork(e.dataExtents, length: e.dataLength)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
