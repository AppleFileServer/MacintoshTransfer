import Foundation
import Testing
@testable import MacintoshTransferKit

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
        #expect(Preferences().scsiID == 6)
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

    /// M4: 1.0's settings carried over once, and left for 1.0.
    @Test func preferencesFromOneDotZero() throws {
        let defaults = try #require(UserDefaults(suiteName: "mtu-test-\(UUID().uuidString)"))
        defaults.set(Data(#"{"scsiID":4,"folderPath":"/tmp/old"}"#.utf8), forKey: Preferences.oldKey)
        let p = Preferences.load(from: defaults)
        #expect(p.scsiID == 4 && p.folderPath == "/tmp/old")
        #expect(defaults.data(forKey: Preferences.key) != nil && defaults.data(forKey: Preferences.oldKey) != nil)
        var q = p
        q.scsiID = 3
        q.save(to: defaults)
        #expect(Preferences.load(from: defaults).scsiID == 3)
        #expect(defaults.data(forKey: Preferences.oldKey) == Data(#"{"scsiID":4,"folderPath":"/tmp/old"}"#.utf8))
    }

    /// M5: ~/Documents/Macintosh Transfer, unless 1.0's folder is there.
    @Test func defaultFolder() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("mtu-build-home-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: home) }
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        #expect(Preferences.defaultFolder(home: home).path.hasSuffix("Documents/Macintosh Transfer"))
        try FileManager.default.createDirectory(at: home.appendingPathComponent("Music/MacMusic Transfer"),
                                                withIntermediateDirectories: true)
        #expect(Preferences.defaultFolder(home: home).path.hasSuffix("Music/MacMusic Transfer"))
    }
}
