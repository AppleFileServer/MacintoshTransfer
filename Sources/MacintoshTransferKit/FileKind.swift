import Foundation
import UniformTypeIdentifiers

/// The kinds of file the image can hold (SPECIFICATION.md §15.9-15.10;
/// M9, K1): each has its folder, type, creator, Mac name rule, validator
/// and words. A file is recognised by its content; its extension is only a
/// hint. In the order of the folders on the volume (M11): T3 adds MacPaint
/// and the two PICTs after the WAVs.
public enum FileKind: String, Sendable, CaseIterable, Codable {
    case wav

    /// What it is, for lists of what the app takes: "MacMusic WAVs".
    public var plural: String {
        switch self {
        case .wav: "MacMusic WAVs"
        }
    }

    /// What a file of this kind is called, as in "It isn't a WAV file".
    public var noun: String {
        switch self {
        case .wav: "WAV file"
        }
    }

    /// Its folder on the volume (M11).
    public var folder: String {
        switch self {
        case .wav: "WAV Files"
        }
    }

    public var fileType: String {
        switch self {
        case .wav: "WAVE"
        }
    }

    public var fileCreator: String {
        switch self {
        case .wav: "????"
        }
    }

    /// The extension its Mac names end in (Q8, M12).
    public var macExtension: String {
        switch self {
        case .wav: ".wav"
        }
    }

    /// The extensions that hint at it (K2, K3): only hints.
    public var extensions: [String] {
        switch self {
        case .wav: ["wav"]
        }
    }

    /// For the Open panel.
    public var contentType: UTType {
        switch self {
        case .wav: .wav
        }
    }

    /// Whether these, the file's first bytes, are this kind's (K2).
    func matches(_ head: Data) -> Bool {
        switch self {
        case .wav:
            head.count >= 12 && head.prefix(4) == Data("RIFF".utf8) && head.subdata(in: 8..<12) == Data("WAVE".utf8)
        }
    }

    /// How many of the first bytes `matches` needs.
    static let headBytes = 512

    /// The kind its content says it is, or nil.
    public static func recognise(_ head: Data) -> FileKind? {
        allCases.first { $0.matches(head) }
    }

    public static func recognise(_ url: URL) -> FileKind? {
        guard let h = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? h.close() }
        return recognise((try? h.read(upToCount: headBytes)) ?? Data())
    }

    /// The kind its name hints at, or nil.
    public static func hinted(by url: URL) -> FileKind? {
        let ext = url.pathExtension.lowercased()
        return allCases.first { $0.extensions.contains(ext) }
    }

    /// Everything the app takes, in words: "MacMusic WAVs".
    public static var listing: String {
        let names = allCases.map(\.plural)
        return names.count <= 2 ? names.joined(separator: " and ")
            : names.dropLast().joined(separator: ", ") + " and " + names.last!
    }

    /// The kinds among some files, in the folders' order.
    public static func present<S: Sequence>(_ kinds: S) -> [FileKind] where S.Element == FileKind {
        let set = Set(kinds)
        return allCases.filter { set.contains($0) }
    }
}

/// What a file holds, as its kind's validator read it.
public enum FileDetails: Sendable {
    case wav(MacMusicWAVReport)

    /// Why it can't go on the image, or nil.
    var problem: String? {
        switch self {
        case .wav(let r):
            guard r.accepted else {
                return "It isn't in MacMusic's format: " + r.problems.joined(separator: " ")
                    + " Convert it with the MacMusic Converter Utility first."
            }
            return nil
        }
    }

    /// How long it plays, for a kind that plays.
    public var duration: Double? {
        switch self {
        case .wav(let r): r.duration
        }
    }
}
