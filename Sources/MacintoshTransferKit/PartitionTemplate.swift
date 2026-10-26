import Foundation

/// The template (decisions Q2, Q3): the first 96 blocks of a BlueSCSI
/// image known to work on the Macintosh Plus: the driver descriptor, the
/// Apple partition map and Apple SCSI Driver 4.3, with an Apple_HFS
/// partition starting at block 96. It's used as it is; only its size
/// fields are set for each image. It holds Apple's driver, so it is never
/// part of the repository.
public struct PartitionTemplate: Sendable, Equatable {
    public static let blocks = 96
    public static let bytes = blocks * 512

    public let data: Data

    public enum Problem: Error, Equatable, Sendable {
        case unreadable(String)
        case tooShort
        case noDriverDescriptor
        case notFiveTwelve(Int)
        case noPartitionMap
        case noAppleDriver43
        case noHFSPartition
        case hfsPartitionNotAtBlock96(Int)
    }

    /// The default: the app's own copy (R2), or, run from the repository,
    /// MacMusic's archived copy (Q3).
    public static var standard: URL { Bundled.template ?? archived }

    /// MacMusic's archived copy (Q3), outside every repository.
    public static var archived: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("MacPlusProjects/environment-1.0/bluescsi-template.hda")
    }

    /// Reads and checks a template: any BlueSCSI image will do, only its
    /// first 96 blocks are used.
    public static func load(_ url: URL) throws -> PartitionTemplate {
        let data: Data
        do {
            let h = try FileHandle(forReadingFrom: url)
            defer { try? h.close() }
            data = try h.read(upToCount: bytes) ?? Data()
        } catch {
            throw Problem.unreadable(error.localizedDescription)
        }
        guard data.count == bytes else { throw Problem.tooShort }
        let t = PartitionTemplate(data: data)
        try t.check()
        return t
    }

    /// The map's entries: (type, name, first block, block count).
    public var entries: [(type: String, name: String, start: Int, count: Int)] {
        var found: [(String, String, Int, Int)] = []
        for i in 1..<Self.blocks {
            let e = 512 * i
            guard data[e] == 0x50, data[e + 1] == 0x4D else { break }           // "PM"
            found.append((Self.text(data, e + 48, 32), Self.text(data, e + 16, 32),
                          Int(data.uint32(at: e + 8)), Int(data.uint32(at: e + 12))))
        }
        return found
    }

    func check() throws {
        guard data[0] == 0x45, data[1] == 0x52 else { throw Problem.noDriverDescriptor }   // "ER"
        let blockSize = Int(data.uint16(at: 2))
        guard blockSize == 512 else { throw Problem.notFiveTwelve(blockSize) }
        let map = entries
        guard map.first?.type == "Apple_partition_map" else { throw Problem.noPartitionMap }
        guard map.contains(where: { $0.type == "Apple_Driver43" }) else { throw Problem.noAppleDriver43 }
        guard let hfs = map.first(where: { $0.type == "Apple_HFS" }) else { throw Problem.noHFSPartition }
        guard hfs.start == Self.blocks else { throw Problem.hfsPartitionNotAtBlock96(hfs.start) }
    }

    /// The first 96 blocks for a disk of `totalBlocks`: the descriptor's
    /// size (sbBlkCount) set, and the HFS partition (pmPartBlkCnt, pmDataCnt)
    /// made to reach the end. Nothing else changed.
    public func header(totalBlocks: Int) -> Data {
        var h = data
        h.setUInt32(UInt32(totalBlocks), at: 4)
        let part = UInt32(totalBlocks - Self.blocks)
        for i in 1..<Self.blocks {
            let e = 512 * i
            guard h[e] == 0x50, h[e + 1] == 0x4D else { break }
            if Self.text(h, e + 48, 32) == "Apple_HFS" {
                h.setUInt32(part, at: e + 12)
                h.setUInt32(part, at: e + 84)
            }
        }
        return h
    }

    static func text(_ d: Data, _ at: Int, _ length: Int) -> String {
        let bytes = d[(d.startIndex + at)..<(d.startIndex + at + length)]
        return String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
    }
}

extension Data {
    func uint16(at o: Int) -> UInt16 {
        UInt16(self[startIndex + o]) << 8 | UInt16(self[startIndex + o + 1])
    }
    func uint32(at o: Int) -> UInt32 {
        (0..<4).reduce(UInt32(0)) { $0 << 8 | UInt32(self[startIndex + o + $1]) }
    }
    mutating func setUInt32(_ v: UInt32, at o: Int) {
        for i in 0..<4 { self[startIndex + o + i] = UInt8(truncatingIfNeeded: v >> (24 - 8 * UInt32(i))) }
    }
}
