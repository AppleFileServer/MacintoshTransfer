import CryptoKit
import Foundation

/// A WAV in the queue: what it is, read from the file itself (§4; V1), and
/// its name on the Mac (§5; V2).
public struct QueuedFile: Sendable, Identifiable {
    public var id: URL { source }
    public let source: URL
    public let size: Int
    public let report: MacMusicWAVReport
    /// SHA-256 of the whole file, for spotting identical files (V3) and for
    /// checking the copy.
    public let sha256: String
    /// Its name on the Mac, set by `Queue.assignNames`; empty for a file
    /// that can't go on the disk.
    public internal(set) var macName: String

    /// Why it can't go on the image, or nil.
    public var problem: String? {
        if report.problems.contains("This is not a WAV file.") {
            return "It isn't a WAV file."
        }
        guard report.accepted else {
            return "It isn't in MacMusic's format: " + report.problems.joined(separator: " ")
                + " Convert it with the MacMusic Converter Utility first."
        }
        return nil
    }

    /// The name was changed to suit the Mac.
    public var renamed: Bool { !macName.isEmpty && macName != source.lastPathComponent }

    /// What the file is, in a few words: "WAV PCM, 22,050 Hz, mono, 8-bit, 3:38".
    public var description: String {
        let r = report
        guard r.formatTag != 0 else { return "not a WAV file" }
        let format = r.formatTag == 1 ? "PCM" : String(format: "format 0x%04X", r.formatTag)
        let channels = r.channels == 1 ? "mono" : r.channels == 2 ? "stereo" : "\(r.channels) channels"
        let s = Int(r.duration.rounded())
        return "WAV \(format), \(r.sampleRate.formatted()) Hz, \(channels), \(r.bitsPerSample)-bit, "
            + String(format: "%d:%02d", s / 60, s % 60)
    }

    public static func inspect(_ url: URL) -> QueuedFile {
        let data = (try? Data(contentsOf: url)) ?? Data()
        let sha = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return QueuedFile(source: url, size: data.count, report: MacMusicWAVValidator.check(url),
                          sha256: sha, macName: url.lastPathComponent)
    }
}

/// The queue of WAVs for one image.
public struct Queue: Sendable {
    public private(set) var files: [QueuedFile] = []
    /// Notes from the last change: duplicates ignored, identical files (V3).
    public private(set) var notes: [String] = []

    public init() {}

    /// Adds files: the same file twice is ignored (V3); folders and missing
    /// files are noted and skipped. Names are then (re)assigned.
    public mutating func add(_ urls: [URL]) {
        notes = []
        for url in urls {
            let real = url.resolvingSymlinksInPath().standardizedFileURL
            var isFolder: ObjCBool = false
            guard FileManager.default.fileExists(atPath: real.path, isDirectory: &isFolder) else {
                notes.append("\"\(url.lastPathComponent)\" couldn't be found.")
                continue
            }
            guard !isFolder.boolValue else {
                notes.append("\"\(url.lastPathComponent)\" is a folder: add the WAV files in it.")
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

    /// Every file's name on the Mac (V2): MacNames' rules, then clashes (as
    /// HFS sees them, ignoring case) made unique, "Song 2.wav", in list order.
    /// Files that can't go on the disk get no name, and take none.
    mutating func assignNames() {
        var taken = Set<String>()
        for i in files.indices {
            guard files[i].problem == nil else {
                files[i].macName = ""
                continue
            }
            let base = (files[i].source.lastPathComponent as NSString).deletingPathExtension
            var n = 1, name = MacNames.name(base)
            while taken.contains(MacNames.key(name)) {
                n += 1
                name = MacNames.name(base, suffix: " \(n)")
            }
            taken.insert(MacNames.key(name))
            files[i].macName = name
        }
    }

    public var ready: [QueuedFile] { files.filter { $0.problem == nil } }
    public var refused: [QueuedFile] { files.filter { $0.problem != nil } }
    public var totalBytes: Int { files.reduce(0) { $0 + $1.size } }
    /// What the files that can go on the disk add up to (for the estimate).
    public var readyBytes: Int { ready.reduce(0) { $0 + $1.size } }
    public var totalSeconds: Double { files.reduce(0) { $0 + $1.report.duration } }
    public var canBuild: Bool { !files.isEmpty && refused.isEmpty }
}

/// Names on the classic Mac (§5; Q8, V2), as the MacMusic Converter Utility
/// makes them (its OutputNaming): Mac Roman, letters it can't hold
/// transliterated; no colons, slashes or control characters; not hidden;
/// at most 31 characters with ".wav", cut at a word.
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
    public static func name(_ base: String, suffix: String = "") -> String {
        let room = maximum - ".wav".count - suffix.count
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
        return name + suffix + ".wav"
    }

    /// How HFS compares names: ignoring case.
    public static func key(_ name: String) -> String { name.lowercased() }
}
