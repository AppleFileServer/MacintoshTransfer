import Foundation
import Testing
@testable import MacintoshTransferKit

/// The queue: what each file is, its name on the Mac, duplicates (V1-V3).
@Suite struct QueueTests {
    let f: Fixtures
    init() throws { f = try Fixtures() }

    @Test func aMacMusicWAVIsReady() throws {
        var q = Queue()
        q.add([try f.wav("song.wav", seconds: 3)])
        let x = try #require(q.files.first)
        #expect(x.problem == nil && q.canBuild)
        #expect(x.description == "WAV PCM, 22,254 Hz, mono, 8-bit, 0:03")
        #expect(x.macName == "song.wav" && !x.renamed)
    }

    /// Each kind of wrong file: named, with its real properties, and why.
    @Test func otherFilesAreRefused() throws {
        var q = Queue()
        let text = f.url("notes.wav")
        try Data("not audio at all".utf8).write(to: text)
        q.add([try f.anyWAV("stereo.wav", channels: 2),
               try f.anyWAV("cd.wav", channels: 2, rate: 44_100, bits: 16),
               try f.anyWAV("fast.wav", rate: 44_100),
               try f.anyWAV("ext.wav", format: 0xFFFE),
               try f.anyWAV("cut.wav", seconds: 2, cut: 20_000),
               try f.anyWAV("empty.wav", seconds: 0),
               text])
        #expect(q.refused.count == 7 && !q.canBuild)
        let cd = q.files.first { $0.source.lastPathComponent == "cd.wav" }!
        #expect(cd.description == "WAV PCM, 44,100 Hz, stereo, 16-bit, 0:01")
        #expect(cd.problem?.contains("MacMusic Converter Utility") == true)
        #expect(q.files.first { $0.source.lastPathComponent == "notes.wav" }!.problem == "It isn't a WAV file, though its name ends in .wav.")
        #expect(q.files.first { $0.source.lastPathComponent == "cut.wav" }!.problem?.contains("past the end") == true)
    }

    /// Only the Converter 1.1's rate, the Plus's own: 22,254 Hz, its byte
    /// rate the same (W1, W2). Songs made at 22,050 Hz need converting again.
    @Test func theRate() throws {
        var q = Queue()
        q.add([try f.wav("new.wav", seconds: 2.5),
               try f.wav("old.wav", seconds: 1, rate: 22_050),
               try f.anyWAV("near.wav", rate: 22_255),
               try f.anyWAV("odd.wav", byteRate: 22_050)])
        let x = q.files.map(\.problem)
        #expect(x[0] == nil && q.files[0].duration == 2.5)
        #expect(x[1]?.contains("Its sample rate is 22050 Hz, not 22254.") == true)
        #expect(x[1]?.contains("MacMusic Converter Utility") == true)
        #expect(x[2]?.contains("Its sample rate is 22255 Hz, not 22254.") == true)
        #expect(x[3]?.contains("inconsistent (block align 1, byte rate 22050)") == true)
        #expect(q.refused.count == 3)
    }

    /// A file's kind is its content's; its extension only a hint (M9, K2).
    @Test func kindsByContent() throws {
        let dat = f.url("Song.dat"), bare = f.url("Tune"), text = f.url("notes.txt")
        try Data(contentsOf: try f.wav("x1.wav", seconds: 1, seed: 1)).write(to: dat)
        try Data(contentsOf: try f.wav("x2.wav", seconds: 1, seed: 2)).write(to: bare)
        try Data("not audio at all".utf8).write(to: text)
        var q = Queue()
        q.add([dat, bare, text])
        #expect(q.files.map(\.kind) == [.wav, .wav, nil])
        #expect(q.files.map(\.macName) == ["Song.wav", "Tune.wav", ""])
        #expect(q.files.map(\.folder) == ["WAV Files", "WAV Files", nil])
        #expect(q.files[2].problem == "It isn't a kind of file that can go on the disk (MacMusic WAVs).")
        #expect(q.files[2].duration == nil && !q.files[2].description.isEmpty)
        #expect(q.folders == ["WAV Files"] && q.hasDurations)
        q.remove([q.files[0].source, q.files[1].source])
        #expect(q.folders.isEmpty && !q.hasDurations)
    }

    @Test func kinds() {
        #expect(FileKind.allCases == [.wav])
        let wav = FileKind.wav
        #expect(wav.folder == "WAV Files" && wav.fileType == "WAVE" && wav.fileCreator == "????")
        #expect(wav.macExtension == ".wav" && FileKind.listing == "MacMusic WAVs")
        #expect(FileKind.hinted(by: URL(fileURLWithPath: "/x/A.WAV")) == .wav)
        #expect(FileKind.hinted(by: URL(fileURLWithPath: "/x/A.aif")) == nil)
        #expect(FileKind.recognise(Data("RIFF\0\0\0\0WAVE".utf8)) == .wav)
        #expect(FileKind.recognise(Data("RIFF\0\0\0\0AVI ".utf8)) == nil)
        #expect(FileKind.recognise(Data("RIFF".utf8)) == nil)
        #expect(FileKind.present([.wav, .wav]) == [.wav] && FileKind.present([]) == [])
        #expect(Layout.describe(["WAV Files"]) == "folder \"WAV Files\"")
        #expect(Layout.describe(["WAV Files", "PICT Files"]) == "folders \"WAV Files\", \"PICT Files\"")
    }

    @Test func macNames() {
        #expect(MacNames.name("Good Luck, Babe!") == "Good Luck, Babe!.wav")
        #expect(MacNames.name("AC/DC: Live") == "AC-DC- Live.wav")
        #expect(MacNames.name("Москва") == "Moskva.wav")
        #expect(MacNames.name("Café") == "Café.wav")
        #expect(MacNames.name("🎵") == "_.wav")
        #expect(MacNames.name(".hidden") == "hidden.wav")
        let long = MacNames.name("Chill Dreamy Lounge by unfeel No Copyright Music")
        #expect(long.count <= 31 && long.hasSuffix(".wav"))
        #expect(MacNames.name(String(repeating: "x", count: 40), suffix: " 12").count == 31)
    }

    /// Clashes as HFS sees them (ignoring case) get " 2", " 3" (V2).
    @Test func clashesAreMadeUnique() throws {
        let a = f.url("a"), b = f.url("b")
        try FileManager.default.createDirectory(at: a, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: b, withIntermediateDirectories: true)
        var q = Queue()
        let one = a.appendingPathComponent("Song.wav"), two = b.appendingPathComponent("SONG.wav")
        let three = b.appendingPathComponent("Song?.wav")
        try Data(contentsOf: try f.wav("x1.wav", seconds: 1, seed: 1)).write(to: one)
        try Data(contentsOf: try f.wav("x2.wav", seconds: 1, seed: 2)).write(to: two)
        try Data(contentsOf: try f.wav("x3.wav", seconds: 1, seed: 3)).write(to: three)
        q.add([one, two, three])
        #expect(q.files.map(\.macName) == ["Song.wav", "SONG 2.wav", "Song?.wav"])
        #expect(Set(q.files.map { MacNames.key($0.macName) }).count == 3)
    }

    /// A refused file takes no Mac name, and isn't counted in the size.
    @Test func refusedFilesTakeNoName() throws {
        let mp3 = f.url("Song.mp3")
        try Data("ID3 not a wav".utf8).write(to: mp3)
        var q = Queue()
        q.add([try f.wav("Song.wav", seconds: 1), mp3])
        #expect(q.files.map(\.macName) == ["Song.wav", ""])
        #expect(q.readyBytes == q.files[0].size && q.totalBytes > q.readyBytes)
        #expect(TransferJob(queue: q, folder: f.folder).totalBytes == q.readyBytes)
    }

    /// The same file twice is ignored; identical files are both kept, noted (V3).
    @Test func duplicates() throws {
        let one = try f.wav("one.wav", seconds: 1)
        let copy = f.url("copy.wav")
        try FileManager.default.copyItem(at: one, to: copy)
        var q = Queue()
        q.add([one, one])
        #expect(q.files.count == 1 && q.notes.first?.contains("already in the list") == true)
        q.add([copy])
        #expect(q.files.count == 2 && q.notes.first?.contains("identical") == true)
        // The folder holding them: its WAVs are already in the list (U5).
        q.add([f.folder, f.url("nothing.wav")])
        #expect(q.files.count == 2)
        #expect(q.notes.filter { $0.contains("already in the list") }.count == 2)
        #expect(q.notes.contains { $0.contains("couldn't be found") })
        q.remove([one.resolvingSymlinksInPath().standardizedFileURL])
        #expect(q.files.count == 1)
        q.clear()
        #expect(q.files.isEmpty && !q.canBuild)
    }
}
