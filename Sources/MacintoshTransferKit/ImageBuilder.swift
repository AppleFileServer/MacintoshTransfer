import CryptoKit
import Foundation

/// A file to put on the image: where it is, and its name on the Mac.
public struct ImageFile: Sendable, Equatable {
    public let source: URL
    public let macName: String
    public init(source: URL, macName: String) {
        self.source = source
        self.macName = macName
    }
}

/// The image's layout (§5; decisions Q2, Q10): an HFS volume "Transfer"
/// holding a folder "WAV Files" with the WAVs.
public enum Layout {
    public static let volumeName = "Transfer"
    public static let folderName = "WAV Files"
    public static let fileType = "WAVE"
    public static let fileCreator = "????"
}

/// How big to make the image (Q6): the files plus 25%, plus 4 MB for HFS's
/// own structures, rounded up to a whole MB; at least 10 MB; at most 2 GB
/// (System 6's largest volume).
public enum Sizing {
    public static let minimumBytes = 10 * 1_048_576
    public static let maximumBytes = 2_147_483_648 - PartitionTemplate.bytes
    public static let overheadBytes = 4 * 1_048_576

    public static func imageBytes(forFiles total: Int) -> Int {
        let wanted = total + total / 4 + overheadBytes + PartitionTemplate.bytes
        let mb = (wanted + 1_048_575) / 1_048_576 * 1_048_576
        return max(mb, minimumBytes)
    }

    public static func fits(_ imageBytes: Int) -> Bool { imageBytes - PartitionTemplate.bytes <= maximumBytes }
}

/// Builds and checks an image (Stage 1, the proof; Stage 2 adds the
/// checks on the WAVs and their names, progress and cancelling).
public struct ImageBuilder: Sendable {
    public let template: PartitionTemplate
    public let hfsutils: HFSUtils

    public init(template: PartitionTemplate, hfsutils: HFSUtils) {
        self.template = template
        self.hfsutils = hfsutils
    }

    public enum Problem: Error, Equatable, Sendable {
        case tooLarge(Int)
        case doesNotFit(needed: Int, free: Int)
    }

    /// Writes the image to `output` (which must not exist yet): the
    /// template's 96 blocks sized for the disk, then the HFS partition,
    /// formatted in place by hfsutils, with the folder and the files.
    public func build(_ files: [ImageFile], imageBytes: Int, to output: URL,
                      progress: @escaping @Sendable (TransferProgress) -> Void = { _ in }) async throws {
        guard Sizing.fits(imageBytes) else { throw Problem.tooLarge(imageBytes) }
        let totalBlocks = imageBytes / 512
        FileManager.default.createFile(atPath: output.path, contents: nil)
        let h = try FileHandle(forWritingTo: output)
        try h.write(contentsOf: template.header(totalBlocks: totalBlocks))
        try h.truncate(atOffset: UInt64(totalBlocks * 512))          // the rest: zeroes (sparse)
        try h.close()

        try Task.checkCancellation()
        progress(TransferProgress(stage: .formatting, detail: nil, fraction: nil))
        try await hfsutils.run("hformat", [.option("-l"), .hfsPath(Layout.volumeName), .hostPath(output.path), .option("1")])
        try await hfsutils.run("hmount", [.hostPath(output.path), .option("1")])
        do {
            let free = try await freeBytes()
            let needed = try files.reduce(0) { $0 + (try Self.size($1.source)) }
            guard needed <= free else { throw Problem.doesNotFit(needed: needed, free: free) }
            try await hfsutils.run("hmkdir", [.hfsPath(":" + Layout.folderName)])
            for (i, f) in files.enumerated() {
                try Task.checkCancellation()
                progress(TransferProgress(stage: .copying, detail: "\(i + 1) of \(files.count): \(f.macName)",
                                          fraction: Double(i) / Double(max(files.count, 1))))
                let to = HFSUtils.Argument.hfsPath(":\(Layout.folderName):\(f.macName)")
                // -r: raw, the data fork only; "--" so no path is read as an option.
                try await hfsutils.run("hcopy", [.option("-r"), .option("--"), .hostPath(f.source.path), to])
                // hattrib takes no "--"; its argument is an HFS path, starting
                // with ":", so it can't be read as an option.
                try await hfsutils.run("hattrib", [.option("-t"), .option(Layout.fileType),
                                                   .option("-c"), .option(Layout.fileCreator), to])
            }
        } catch {
            _ = try? await hfsutils.run("humount", [])
            throw error
        }
        try await hfsutils.run("humount", [])
    }

    /// The mounted volume's free space, from hvol.
    func freeBytes() async throws -> Int {
        let text = try await hfsutils.run("hvol", [])
        for line in text.split(separator: "\n") where line.contains("bytes free") {
            if let n = line.split(separator: " ").compactMap({ Int($0) }).first { return n }
        }
        return 0
    }

    static func size(_ url: URL) throws -> Int {
        (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
    }
}

/// Checks a finished image without hfsutils (Q5): its partition map and
/// driver are the template's, its volume and folder are named as they
/// should be, and it holds exactly the files given, each the same size and
/// SHA-256 as its source, with no resource fork.
public enum ImageVerifier {
    public struct Report: Sendable {
        public var problems: [String] = []
        public var checks: [String] = []
        public var passed: Bool { problems.isEmpty }
    }

    public static func verify(_ image: URL, files: [ImageFile], template: PartitionTemplate) -> Report {
        var r = Report()
        func ok(_ s: String) { r.checks.append(s) }
        func bad(_ s: String) { r.problems.append(s) }

        // The disk's structures: exactly the template's, sized.
        let size = (try? FileManager.default.attributesOfItem(atPath: image.path)[.size] as? Int) ?? 0
        guard size > PartitionTemplate.bytes, size % 512 == 0 else {
            bad("the image is \(size) bytes, not a whole number of 512-byte blocks after the map")
            return r
        }
        if let head = try? HFSReader.read(image, 0, PartitionTemplate.bytes),
           head == template.header(totalBlocks: size / 512) {
            ok("the driver descriptor, partition map and Apple Driver 4.3 are the template's, sized for \(size / 512) blocks")
        } else {
            bad("the first 96 blocks aren't the template's (the partition map or driver differ)")
        }

        // The volume, read independently.
        let reader: HFSReader
        do { reader = try HFSReader(image) } catch {
            bad("the HFS volume couldn't be read: \(error)")
            return r
        }
        if reader.partitionOffset == PartitionTemplate.bytes, reader.partitionOffset + reader.partitionLength == size {
            ok("the HFS partition runs from block 96 to the end")
        } else {
            bad("the HFS partition doesn't run from block 96 to the end")
        }
        reader.volumeName == Layout.volumeName ? ok("the volume is named \"\(Layout.volumeName)\"")
                                               : bad("the volume is named \"\(reader.volumeName)\"")
        let root = reader.contents(of: HFSReader.rootID)
        guard let folder = root.first(where: { $0.isFolder && $0.name == Layout.folderName }) else {
            bad("there's no \"\(Layout.folderName)\" folder")
            return r
        }
        root.count == 1 ? ok("the volume holds only the \"\(Layout.folderName)\" folder")
                        : bad("the volume holds more than the folder: \(root.map(\.name))")
        let inside = reader.contents(of: folder.id)
        let expected = Set(files.map(\.macName))
        let actual = Set(inside.map(\.name))
        if expected == actual { ok("the folder holds exactly the \(files.count) files") }
        else { bad("the folder holds \(actual.sorted()), not \(expected.sorted())") }

        for f in files {
            guard let e = inside.first(where: { $0.name == f.macName }) else { continue }
            guard let data = try? Data(contentsOf: f.source) else { bad("\(f.source.path) can't be read"); continue }
            let want = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            let got = (try? reader.sha256(of: e)) ?? "unreadable"
            if e.dataLength == data.count, got == want, e.resourceLength == 0,
               e.type == Layout.fileType {
                ok("\"\(f.macName)\": \(data.count) bytes, SHA-256 matches, type \(e.type), no resource fork")
            } else {
                bad("\"\(f.macName)\": length \(e.dataLength) (source \(data.count)), SHA-256 \(got == want ? "matches" : "differs"), resource fork \(e.resourceLength), type \(e.type)")
            }
        }
        return r
    }
}
