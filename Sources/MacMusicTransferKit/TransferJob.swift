import Foundation

/// What to do when an image of that name is already in the folder (§7; V5).
public enum ExistingImage: Sendable, Equatable {
    case refuse
    case replace
    /// "HD60_512 Transfer 2.hda": valid (BlueSCSI ignores the text after
    /// _512), but the same ID, so only one belongs on the card.
    case keepBoth
}

/// Where a job has got to (§7; V4). `detail` says more ("3 of 12");
/// `fraction` only where it's real (the files copied so far).
public struct TransferProgress: Sendable, Equatable {
    public enum Stage: String, Sendable {
        case checking = "Checking the files"
        case preparing = "Preparing the disk"
        case formatting = "Formatting the HFS volume"
        case copying = "Copying the files"
        case verifying = "Verifying the disk"
        case finishing = "Finishing"
    }
    public let stage: Stage
    public let detail: String?
    public let fraction: Double?

    public init(stage: Stage, detail: String?, fraction: Double?) {
        self.stage = stage
        self.detail = detail
        self.fraction = fraction
    }
}

/// The result (§7; V7): the image, every file's "from → to", and the
/// checks it passed.
public struct TransferResult: Sendable {
    public struct File: Sendable {
        public let source: URL
        public let macName: String
        public let size: Int
        public let sha256: String
    }
    public let image: URL
    public let imageBytes: Int
    public let freeBytes: Int
    public let scsiID: Int
    public let files: [File]
    public let checks: [String]
    public let warnings: [String]

    /// The summary, as text to copy.
    public var summary: String {
        var lines = ["\(image.lastPathComponent): SCSI ID \(scsiID), \(imageBytes / 1_048_576) MB, "
                     + "volume \"\(Layout.volumeName)\", folder \"\(Layout.folderName)\", \(files.count) file(s)."]
        for f in files {
            let from = f.source.lastPathComponent
            lines.append("  \(from == f.macName ? from : "\(from) → \(f.macName)")  \(f.size) bytes  SHA-256 \(f.sha256)")
        }
        lines.append("Checked:")
        lines += checks.map { "  ✓ \($0)" }
        lines += warnings.map { "Note: \($0)" }
        return lines.joined(separator: "\n")
    }
}

public enum TransferError: Error, Equatable, Sendable {
    case emptyQueue
    case refusedFiles([String])
    case badID(Int)
    case tooLarge(Int)
    case destinationUnavailable(String)
    case imageExists(String)
    case sourceChanged(String)
    case template(String)
    case hfsutils(String)
    case insufficientSpace(needed: Int, available: Int)
    case doesNotFit(needed: Int, free: Int)
    case verificationFailed([String])
    case cancelled

    public var message: String {
        switch self {
        case .emptyQueue: "Add some WAV files first."
        case .refusedFiles(let names): "These files can't go on the disk: \(names.joined(separator: ", ")). Remove them, or convert them with the MacMusic Converter Utility."
        case .badID(let id): "SCSI ID \(id) can't be used: choose 0 to 6 (7 is the Mac itself)."
        case .tooLarge(let n): "\(n / 1_048_576) MB of files is too much: a System 6 disk holds at most 2 GB."
        case .destinationUnavailable(let p): "The folder to save in isn't available, or can't be written to: \(p)"
        case .imageExists(let p): "\(URL(fileURLWithPath: p).lastPathComponent) is already in that folder."
        case .sourceChanged(let n): "\"\(n)\" changed or disappeared after it was added. Add it again."
        case .template(let why): "The disk template can't be used: \(why)"
        case .hfsutils(let why): "The disk couldn't be made: \(why)"
        case .insufficientSpace(let needed, let available): "There isn't room for the disk image: it needs \(needed / 1_048_576) MB, and \(available / 1_048_576) MB is free."
        case .doesNotFit(let needed, let free): "The files (\(needed) bytes) don't fit in the formatted volume (\(free) bytes free)."
        case .verificationFailed(let problems): "The finished disk failed its checks, so it wasn't kept: " + problems.joined(separator: "; ")
        case .cancelled: "Cancelled. Nothing was saved."
        }
    }
}

/// One image from a queue (the packaging engine, §7; V4-V7).
public struct TransferJob: Sendable {
    public var files: [QueuedFile]
    public var folder: URL
    public var scsiID: Int
    public var existing: ExistingImage
    public var template: URL

    public init(queue: Queue, folder: URL, scsiID: Int = BlueSCSI.defaultID,
                existing: ExistingImage = .refuse, template: URL = PartitionTemplate.archived) {
        self.files = queue.files
        self.folder = folder
        self.scsiID = scsiID
        self.existing = existing
        self.template = template
    }

    /// The files that can go on the disk (a job with any others is refused).
    public var totalBytes: Int { files.filter { $0.problem == nil }.reduce(0) { $0 + $1.size } }
    public var imageBytes: Int { Sizing.imageBytes(forFiles: totalBytes) }

    /// The image's name, and where it will go: by the ID, with " 2", " 3"
    /// when keeping both (V5).
    public func destination() throws -> URL {
        let first = folder.appendingPathComponent(BlueSCSI.imageName(id: scsiID))
        guard FileManager.default.fileExists(atPath: first.path) else { return first }
        switch existing {
        case .refuse: throw TransferError.imageExists(first.path)
        case .replace: return first
        case .keepBoth:
            for n in 2...99 {
                let url = folder.appendingPathComponent(BlueSCSI.imageName(id: scsiID, label: "Transfer \(n)"))
                if !FileManager.default.fileExists(atPath: url.path) { return url }
            }
            throw TransferError.imageExists(first.path)
        }
    }

    /// How the size was reached (V6), in words.
    public var sizeExplanation: String {
        let mb = { (b: Int) in String(format: "%.1f MB", Double(b) / 1_048_576) }
        return "\(mb(totalBytes)) of files, plus 25% for adding more, plus 4 MB for the disk's own structures, "
            + "rounded up to a whole MB (at least 10 MB): \(imageBytes / 1_048_576) MB."
    }
}

/// Builds the image for a job.
public struct TransferEngine: Sendable {
    let hfsHelpers: URL?
    /// For the tests only: skip the free-space check, to see a disk filling
    /// mid-write handled.
    var checksSpace = true

    public init(hfsHelpers: URL? = nil) { self.hfsHelpers = hfsHelpers }

    public func run(_ job: TransferJob,
                    progress: @escaping @Sendable (TransferProgress) -> Void = { _ in }) async throws -> TransferResult {
        do {
            return try await perform(job, progress)
        } catch is CancellationError {
            throw TransferError.cancelled
        } catch RawSpawn.Problem.cancelled {
            throw TransferError.cancelled
        }
    }

    func perform(_ job: TransferJob, _ progress: @escaping @Sendable (TransferProgress) -> Void) async throws -> TransferResult {
        let files = FileManager.default
        progress(TransferProgress(stage: .checking, detail: nil, fraction: nil))
        guard !job.files.isEmpty else { throw TransferError.emptyQueue }
        if BlueSCSI.check(id: job.scsiID) != nil { throw TransferError.badID(job.scsiID) }
        let refused = job.files.filter { $0.problem != nil }
        guard refused.isEmpty else { throw TransferError.refusedFiles(refused.map { $0.source.lastPathComponent }) }
        guard Sizing.fits(job.imageBytes) else { throw TransferError.tooLarge(job.totalBytes) }
        // Each file as it was when it was checked (V1): not changed since.
        for f in job.files {
            let size = (try? files.attributesOfItem(atPath: f.source.path)[.size] as? Int) ?? -1
            guard size == f.size else { throw TransferError.sourceChanged(f.source.lastPathComponent) }
        }
        var isFolder: ObjCBool = false
        guard files.fileExists(atPath: job.folder.path, isDirectory: &isFolder), isFolder.boolValue,
              files.isWritableFile(atPath: job.folder.path) else {
            throw TransferError.destinationUnavailable(job.folder.path)
        }
        let destination = try job.destination()
        if checksSpace, let free = (try? job.folder.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?
            .volumeAvailableCapacityForImportantUsage, Int(free) < job.imageBytes + 1_048_576 {
            throw TransferError.insufficientSpace(needed: job.imageBytes, available: Int(free))
        }
        try Task.checkCancellation()

        // The template, and hfsutils with this job's own HOME.
        progress(TransferProgress(stage: .preparing, detail: nil, fraction: nil))
        let template: PartitionTemplate
        do { template = try PartitionTemplate.load(job.template) } catch { throw TransferError.template("\(error)") }
        let work = files.temporaryDirectory.appendingPathComponent("mtu-job-\(UUID().uuidString)")
        try files.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: work) }
        let hfs: HFSUtils
        do { hfs = try HFSUtils.locate(home: work, helpers: hfsHelpers) } catch { throw TransferError.hfsutils("\(error)") }

        // Built beside its destination, under a hidden name, and moved into
        // place only once verified (§7).
        let temporary = job.folder.appendingPathComponent(".mtu-\(UUID().uuidString).hda.partial")
        defer { try? files.removeItem(at: temporary) }
        let images = job.files.map { ImageFile(source: $0.source, macName: $0.macName) }
        do {
            try await ImageBuilder(template: template, hfsutils: hfs).build(
                images, imageBytes: job.imageBytes, to: temporary) { step in progress(step) }
        } catch ImageBuilder.Problem.doesNotFit(let needed, let free) {
            throw TransferError.doesNotFit(needed: needed, free: free)
        } catch let p as HFSUtils.Problem {
            throw TransferError.hfsutils("\(p)")
        }
        try Task.checkCancellation()

        progress(TransferProgress(stage: .verifying, detail: nil, fraction: nil))
        let report = ImageVerifier.verify(temporary, files: images, template: template)
        guard report.passed else { throw TransferError.verificationFailed(report.problems) }
        // The sources still the files that were checked and copied.
        for f in job.files where QueuedFile.inspect(f.source).sha256 != f.sha256 {
            throw TransferError.sourceChanged(f.source.lastPathComponent)
        }
        try Task.checkCancellation()

        progress(TransferProgress(stage: .finishing, detail: nil, fraction: nil))
        if job.existing == .replace, files.fileExists(atPath: destination.path) {
            _ = try files.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try files.moveItem(at: temporary, to: destination)
        }
        let free = (try? HFSReader(destination).freeBytes) ?? 0
        var warnings = BlueSCSI.warnings(id: job.scsiID)
        if destination.lastPathComponent != BlueSCSI.imageName(id: job.scsiID) {
            warnings.append("This is a second image for ID \(job.scsiID): put only one of them on the card.")
        }
        return TransferResult(
            image: destination, imageBytes: job.imageBytes, freeBytes: free, scsiID: job.scsiID,
            files: job.files.map { .init(source: $0.source, macName: $0.macName, size: $0.size, sha256: $0.sha256) },
            checks: report.checks, warnings: warnings)
    }
}
