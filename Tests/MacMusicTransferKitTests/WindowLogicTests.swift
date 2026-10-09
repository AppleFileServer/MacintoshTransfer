import Foundation
import Testing
@testable import MacMusicTransferKit

/// The window's logic, in the engine so it can be tested (U9).
@Suite struct WindowLogicTests {
    let f: Fixtures
    init() throws { f = try Fixtures() }

    /// A folder adds the WAVs directly in it, not from folders within (U5).
    @Test func aFolderAddsOneLevel() throws {
        let album = f.url("Album"), inner = album.appendingPathComponent("Bonus")
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
        for (n, name) in ["B.wav", "a.wav", "C.WAV"].enumerated() {
            try Data(contentsOf: try f.wav("src\(n).wav", seconds: 1, seed: n)).write(to: album.appendingPathComponent(name))
        }
        try Data(contentsOf: try f.wav("deep.wav", seconds: 1)).write(to: inner.appendingPathComponent("Deep.wav"))
        try Data("x".utf8).write(to: album.appendingPathComponent("cover.jpg"))
        try Data("x".utf8).write(to: album.appendingPathComponent(".hidden.wav"))
        var q = Queue()
        q.add([album])
        #expect(q.files.map(\.source.lastPathComponent) == ["a.wav", "B.wav", "C.WAV"])
        #expect(q.notes.first?.contains("3 WAV file(s) added; 2 other item(s)") == true)
        var empty = Queue()
        empty.add([inner.deletingLastPathComponent().appendingPathComponent("Bonus").deletingLastPathComponent()
                   .appendingPathComponent("Bonus")])
        #expect(empty.files.count == 1)
        let none = f.url("Empty")
        try FileManager.default.createDirectory(at: none, withIntermediateDirectories: true)
        var q2 = Queue()
        q2.add([none])
        #expect(q2.files.isEmpty && q2.notes.first?.contains("no WAV files") == true)
    }

    @Test func preferences() throws {
        let defaults = try #require(UserDefaults(suiteName: "mtu-test-\(UUID().uuidString)"))
        #expect(Preferences.load(from: defaults) == Preferences())
        #expect(Preferences().scsiID == 6 && Preferences().folder.path.hasSuffix("Music/MacMusic Transfer"))
        var p = Preferences()
        p.scsiID = 2
        p.folderPath = "/tmp/x"
        p.templatePath = "/tmp/t.hda"
        p.save(to: defaults)
        #expect(Preferences.load(from: defaults) == p)
        p.scsiID = 9
        p.save(to: defaults)
        #expect(Preferences.load(from: defaults).scsiID == 6)
    }
}
