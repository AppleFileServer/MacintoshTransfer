import Foundation
@testable import MacMusicTransferKit

/// A fresh folder per test, and MacMusic-style WAVs made byte by byte
/// (mono, 22,050 Hz, unsigned 8-bit), so the tests need no audio tools.
struct Fixtures {
    let folder: URL

    init() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("mtu-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    func url(_ name: String) -> URL { folder.appendingPathComponent(name) }

    /// A MacMusic WAV of `seconds` of a tone (`seed` varies it).
    @discardableResult
    func wav(_ name: String, seconds: Double, seed: Int = 1) throws -> URL {
        let n = Int(seconds * 22_050)
        var audio = Data(count: n)
        for i in 0..<n {
            audio[i] = UInt8(clamping: 128 + Int(60 * sin(Double(i * (seed + 3)) / 20)))
        }
        var fmt = Data()
        fmt.le16(1); fmt.le16(1); fmt.le32(22_050); fmt.le32(22_050); fmt.le16(1); fmt.le16(8)
        var body = Data("WAVE".utf8)
        body.append(Data("fmt ".utf8)); body.le32(UInt32(fmt.count)); body.append(fmt)
        body.append(Data("data".utf8)); body.le32(UInt32(audio.count)); body.append(audio)
        if audio.count & 1 == 1 { body.append(0) }
        var file = Data("RIFF".utf8); file.le32(UInt32(body.count)); file.append(body)
        let out = url(name)
        try file.write(to: out)
        return out
    }

    func hfsutils() throws -> HFSUtils {
        let home = url("hfs-home")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        return try HFSUtils.locate(home: home)
    }

    func template() throws -> PartitionTemplate { try PartitionTemplate.load(PartitionTemplate.archived) }
}

extension Data {
    mutating func le16(_ v: UInt16) { append(contentsOf: [UInt8(v & 0xFF), UInt8(v >> 8)]) }
    mutating func le32(_ v: UInt32) { for i in 0..<4 { append(UInt8(truncatingIfNeeded: v >> (8 * UInt32(i)))) } }
}
