import Foundation

/// The packaged app's self-test (Stage 5; R4), as the MacMusic Converter
/// Utility's: run as
/// `Macintosh Transfer Utility.app/Contents/MacOS/MacintoshTransfer --self-test`,
/// it opens no window, uses the app's own hfsutils and template only,
/// makes three short WAVs (one named "Café") in a temporary folder,
/// builds an image of them, has it checked by the independent HFS
/// reader, removes everything it made, and reports.
public enum SelfTest {
    public static func run(helpers: URL?, template: URL?) async -> (passed: Bool, report: [String]) {
        var report = ["Macintosh Transfer Utility \(AppVersion.string): self-test"]
        func fail(_ s: String) -> (Bool, [String]) { report.append("FAIL: " + s); return (false, report) }
        guard let helpers, let template else { return fail("not run from the packaged app") }

        let home = FileManager.default.temporaryDirectory.appendingPathComponent("mtu-job-selftest-\(UUID().uuidString)")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("mtu-build-selftest-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: home)
            try? FileManager.default.removeItem(at: folder)
        }
        do {
            try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
            let hfs = try HFSUtils.locate(home: home, environment: [:], helpers: helpers)
            report.append("ok    hfsutils: \(hfs.folder.path)")
            let t = try PartitionTemplate.load(template)
            report.append("ok    template: \(template.lastPathComponent), \(t.entries.count) partition map entries")
        } catch {
            return fail("\(error)")
        }

        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var files: [URL] = []
            for (i, name) in ["Self Test 1.wav", "Self Test 2.wav", "Café.wav"].enumerated() {
                let url = folder.appendingPathComponent(name)
                try tone(seconds: 1, hertz: 330 + 110 * Double(i)).write(to: url)
                files.append(url)
            }
            var queue = Queue()
            queue.add(files)
            guard queue.canBuild else { return fail("the test files were refused") }
            let r = try await TransferEngine(hfsHelpers: helpers)
                .run(TransferJob(queue: queue, folder: folder, template: template))
            report += r.checks.map { "ok    " + $0 }
            guard r.files.count == 3, r.files.contains(where: { $0.macName == "Café.wav" }) else {
                return fail("the image doesn't hold the three files")
            }
        } catch let e as TransferError {
            return fail(e.message)
        } catch {
            return fail("\(error)")
        }
        report.append("PASSED")
        return (true, report)
    }

    /// A MacMusic WAV: mono, 22,050 Hz, 8-bit unsigned, a sine tone.
    static func tone(seconds: Double, hertz: Double) -> Data {
        let rate = 22_050, count = Int(Double(rate) * seconds)
        var d = Data()
        func u32(_ v: Int) { withUnsafeBytes(of: UInt32(v).littleEndian) { d.append(contentsOf: $0) } }
        func u16(_ v: Int) { withUnsafeBytes(of: UInt16(v).littleEndian) { d.append(contentsOf: $0) } }
        d.append(contentsOf: Array("RIFF".utf8)); u32(36 + count); d.append(contentsOf: Array("WAVE".utf8))
        d.append(contentsOf: Array("fmt ".utf8)); u32(16); u16(1); u16(1); u32(rate); u32(rate); u16(1); u16(8)
        d.append(contentsOf: Array("data".utf8)); u32(count)
        for n in 0..<count {
            d.append(UInt8(128 + 90 * sin(2 * .pi * hertz * Double(n) / Double(rate))))
        }
        if count % 2 == 1 { d.append(0) }
        return d
    }
}
