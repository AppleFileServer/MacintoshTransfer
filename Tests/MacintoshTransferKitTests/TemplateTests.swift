import Foundation
import Testing
@testable import MacintoshTransferKit

@Suite struct TemplateTests {
    let f: Fixtures
    init() throws { f = try Fixtures() }

    @Test func theArchivedTemplate() throws {
        let t = try f.template()
        let map = t.entries
        #expect(map.map(\.type) == ["Apple_partition_map", "Apple_Driver43", "Apple_HFS"])
        #expect(map[1].start == 64 && map[2].start == 96)
    }

    @Test func sizedHeaderChangesOnlyTheSizes() throws {
        let t = try f.template()
        let h = t.header(totalBlocks: 20_480)
        #expect(h.uint32(at: 4) == 20_480)
        let hfs = 512 * 3
        #expect(h.uint32(at: hfs + 12) == 20_480 - 96 && h.uint32(at: hfs + 84) == 20_480 - 96)
        var changed: [Int] = []
        for i in 0..<h.count where h[i] != t.data[i] { changed.append(i) }
        #expect(changed.allSatisfy { (4..<8).contains($0) || (hfs + 12..<hfs + 16).contains($0) || (hfs + 84..<hfs + 88).contains($0) })
        #expect(h[(64 * 512)...] == t.data[(64 * 512)...])          // the driver untouched
    }

    @Test func badTemplatesAreRefused() throws {
        let junk = f.url("junk.hda")
        try Data(repeating: 7, count: 96 * 512).write(to: junk)
        #expect(throws: PartitionTemplate.Problem.noDriverDescriptor) { try PartitionTemplate.load(junk) }
        let short = f.url("short.hda")
        try Data(repeating: 0, count: 1000).write(to: short)
        #expect(throws: PartitionTemplate.Problem.tooShort) { try PartitionTemplate.load(short) }
        // The real one with its driver entry renamed: no Apple Driver 4.3.
        var d = try f.template().data
        let e = 512 * 2 + 48
        d.replaceSubrange(e..<(e + 14), with: Data("Apple_Driver_X".utf8))
        let other = f.url("other.hda")
        try d.write(to: other)
        #expect(throws: PartitionTemplate.Problem.noAppleDriver43) { try PartitionTemplate.load(other) }
    }

    @Test func sizing() {
        #expect(Sizing.imageBytes(forFiles: 0) == 10 * 1_048_576)
        let five = Sizing.imageBytes(forFiles: 5_000_000)                  // 5 MB of WAVs
        #expect(five % 1_048_576 == 0 && five >= 5_000_000 * 5 / 4 + 4 * 1_048_576)
        #expect(Sizing.fits(Sizing.imageBytes(forFiles: 1_000_000_000)))
        #expect(!Sizing.fits(Sizing.imageBytes(forFiles: 1_800_000_000)))
    }
}
