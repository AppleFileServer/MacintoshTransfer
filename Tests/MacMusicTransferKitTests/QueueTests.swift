import Foundation
import Testing
@testable import MacMusicTransferKit

/// The queue: what each file is, its name on the Mac, duplicates (V1-V3).
@Suite struct QueueTests {
    let f: Fixtures
    init() throws { f = try Fixtures() }

    @Test func aMacMusicWAVIsReady() throws {
        var q = Queue()
        q.add([try f.wav("song.wav", seconds: 3)])
        let x = try #require(q.files.first)
        #expect(x.problem == nil && q.canBuild)
        #expect(x.description == "WAV PCM, 22,050 Hz, mono, 8-bit, 0:03")
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
        #expect(q.files.first { $0.source.lastPathComponent == "notes.wav" }!.problem == "It isn't a WAV file.")
        #expect(q.files.first { $0.source.lastPathComponent == "cut.wav" }!.problem?.contains("past the end") == true)
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
        q.add([f.folder, f.url("nothing.wav")])
        #expect(q.files.count == 2 && q.notes.count == 2)
        q.remove([one.resolvingSymlinksInPath().standardizedFileURL])
        #expect(q.files.count == 1)
        q.clear()
        #expect(q.files.isEmpty && !q.canBuild)
    }
}
