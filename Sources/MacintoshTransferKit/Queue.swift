import CryptoKit
import Foundation

/// A file in the queue: its kind and what it holds, read from the file
/// itself (§4; V1, M9), and its name on the Mac (§5; V2).
public struct QueuedFile: Sendable, Identifiable {
    public var id: URL { source }
    public let source: URL
    public let size: Int
    /// Its kind, by its content (K2); nil for a file of no known kind.
    public let kind: FileKind?
    /// What its kind's validator found; nil with no kind.
    public let details: FileDetails?
    /// SHA-256 of the whole file, for spotting identical files (V3) and for
    /// checking the copy.
    public let sha256: String
    /// Its name on the Mac, set by `Queue.assignNames`; empty for a file
    /// that can't go on the disk.
    public internal(set) var macName: String

    /// Why it can't go on the image, or nil.
    public var problem: String? {
        guard let details else {
            if let hint = FileKind.hinted(by: source) {
                return "It isn't a \(hint.noun), though its name ends in .\(source.pathExtension)."
            }
            return "It isn't a kind of file that can go on the disk (\(FileKind.listing))."
        }
        return details.problem
    }

    /// The folder it goes in on the volume, if it can go.
    public var folder: String? { problem == nil ? kind?.folder : nil }

    /// How long it plays, for a kind that plays.
    public var duration: Double? { details?.duration }

    /// The name was changed to suit the Mac.
    public var renamed: Bool { !macName.isEmpty && macName != source.lastPathComponent }

    /// What the file is, in a few words: "WAV PCM, 22,050 Hz, mono, 8-bit, 3:38".
    public var description: String {
        guard case .wav(let r) = details else { return "not a kind of file that can go on the disk" }
        let format = r.formatTag == 1 ? "PCM" : String(format: "format 0x%04X", r.formatTag)
        let channels = r.channels == 1 ? "mono" : r.channels == 2 ? "stereo" : "\(r.channels) channels"
        let s = Int(r.duration.rounded())
        return "WAV \(format), \(r.sampleRate.formatted()) Hz, \(channels), \(r.bitsPerSample)-bit, "
            + String(format: "%d:%02d", s / 60, s % 60)
    }

    public static func inspect(_ url: URL) -> QueuedFile {
        let data = (try? Data(contentsOf: url)) ?? Data()
        let sha = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let kind = FileKind.recognise(data.prefix(FileKind.headBytes))
        let details: FileDetails? = switch kind {
        case .wav: .wav(MacMusicWAVValidator.check(url))
        case nil: nil
        }
        return QueuedFile(source: url, size: data.count, kind: kind, details: details,
                          sha256: sha, macName: url.lastPathComponent)
    }
}

/// The queue of files for one image.
public struct Queue: Sendable {
    public private(set) var files: [QueuedFile] = []
    /// Notes from the last change: duplicates ignored, identical files (V3).
    public private(set) var notes: [String] = []

    public init() {}

    /// Adds files: the same file twice is ignored (V3); a folder adds the
    /// files directly inside it that are a known kind by their content, or
    /// named as one (so a damaged one is still shown with its reason), not
    /// from folders within it (U5, the owner's choice; K3); missing files
    /// are noted. Names are then (re)assigned.
    public mutating func add(_ urls: [URL]) {
        notes = []
        var expanded: [URL] = []
        for url in urls {
            var isFolder: ObjCBool = false
            let real = url.resolvingSymlinksInPath().standardizedFileURL
            if FileManager.default.fileExists(atPath: real.path, isDirectory: &isFolder), isFolder.boolValue {
                let items = (try? FileManager.default.contentsOfDirectory(
                    at: real, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
                let taken = items.filter {
                    (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) != true
                        && (FileKind.hinted(by: $0) != nil || FileKind.recognise($0) != nil)
                }
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                let others = items.count - taken.count
                if taken.isEmpty {
                    notes.append("\"\(url.lastPathComponent)\" has no \(FileKind.listing) directly inside it.")
                } else if others > 0 {
                    notes.append("From \"\(url.lastPathComponent)\": \(taken.count) file(s) added; \(others) other item(s) (including any folders) left out.")
                }
                expanded += taken
            } else {
                expanded.append(url)
            }
        }
        for url in expanded {
            let real = url.resolvingSymlinksInPath().standardizedFileURL
            guard FileManager.default.fileExists(atPath: real.path) else {
                notes.append("\"\(url.lastPathComponent)\" couldn't be found.")
                continue
            }
            if files.contains(where: { $0.source == real }) {
                notes.append("\"\(url.lastPathComponent)\" is already in the list.")
                continue
            }
            let f = QueuedFile.inspect(real)
            if let same = files.first(where: { $0.sha256 == f.sha256 && $0.size == f.size }) {
                notes.append("\"\(url.lastPathComponent)\" is identical to \"\(same.source.lastPathComponent)\"; both will go on the disk.")
            }
            files.append(f)
        }
        assignNames()
    }

    public mutating func remove(_ ids: Set<URL>) {
        files.removeAll { ids.contains($0.source) }
        notes = []
        assignNames()
    }

    public mutating func clear() {
        files = []
        notes = []
    }

    /// Every file's name on the Mac (V2): MacNames' rules with its kind's
    /// extension, then clashes (as HFS sees them, ignoring case, and only
    /// within a folder, M9) made unique, "Song 2.wav", in list order. Files
    /// that can't go on the disk get no name, and take none.
    mutating func assignNames() {
        var taken: [String: Set<String>] = [:]
        for i in files.indices {
            guard files[i].problem == nil, let kind = files[i].kind else {
                files[i].macName = ""
                continue
            }
            let base = (files[i].source.lastPathComponent as NSString).deletingPathExtension
            var n = 1, name = MacNames.name(base, extension: kind.macExtension)
            while taken[kind.folder, default: []].contains(MacNames.key(name)) {
                n += 1
                name = MacNames.name(base, suffix: " \(n)", extension: kind.macExtension)
            }
            taken[kind.folder, default: []].insert(MacNames.key(name))
            files[i].macName = name
        }
    }

    public var ready: [QueuedFile] { files.filter { $0.problem == nil } }
    public var refused: [QueuedFile] { files.filter { $0.problem != nil } }
    public var totalBytes: Int { files.reduce(0) { $0 + $1.size } }
    /// What the files that can go on the disk add up to (for the estimate).
    public var readyBytes: Int { ready.reduce(0) { $0 + $1.size } }
    public var totalSeconds: Double { files.reduce(0) { $0 + ($1.duration ?? 0) } }
    /// Whether any file plays (so a total length means something).
    public var hasDurations: Bool { files.contains { $0.duration != nil } }
    /// The folders the image will hold, in their order (M11).
    public var folders: [String] { FileKind.present(ready.compactMap(\.kind)).map(\.folder) }
    public var canBuild: Bool { !files.isEmpty && refused.isEmpty }
}

/// Names on the classic Mac (§5; Q8, V2), as the MacMusic Converter Utility
/// makes them (its OutputNaming): Mac Roman, letters it can't hold
/// transliterated; no colons, slashes or control characters; not hidden;
/// at most 31 characters with the kind's extension (".wav"), cut at a word.
public enum MacNames {
    public static let maximum = 31

    public static func safe(_ raw: String) -> String {
        var text = raw.precomposedStringWithCanonicalMapping.unicodeScalars.map { s -> String in
            if s.value < 0x20 || s.value == 0x7F { return "" }
            if s == "/" || s == ":" || s == "\\" { return "-" }
            let c = String(s)
            if c.data(using: .macOSRoman) != nil { return c }
            let plain = c.applyingTransform(StringTransform("Any-Latin; Latin-ASCII"), reverse: false) ?? ""
            return !plain.isEmpty && plain.data(using: .macOSRoman) != nil ? plain : "_"
        }.joined()
        text = text.replacingOccurrences(of: "\u{2019}", with: "'")
        while text.hasPrefix(".") || text.hasPrefix(" ") { text.removeFirst() }
        text = text.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? "Untitled" : text
    }

    /// "<base><suffix>.wav", within 31 characters.
    public static func name(_ base: String, suffix: String = "", extension ext: String = FileKind.wav.macExtension) -> String {
        let room = maximum - ext.count - suffix.count
        var name = safe(base)
        if name.count > room {
            let cut = String(name.prefix(room))
            if let space = cut.lastIndex(of: " "), cut.distance(from: cut.startIndex, to: space) >= room / 2 {
                name = String(cut[..<space])
            } else {
                name = cut
            }
            name = name.trimmingCharacters(in: CharacterSet(charactersIn: " ,;-_"))
        }
        return name + suffix + ext
    }

    /// How HFS compares names: ignoring case.
    public static func key(_ name: String) -> String { name.lowercased() }
}
