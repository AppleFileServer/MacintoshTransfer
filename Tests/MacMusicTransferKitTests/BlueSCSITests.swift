import Foundation
import Testing
@testable import MacMusicTransferKit

@Suite struct BlueSCSITests {
    @Test func names() {
        #expect(BlueSCSI.imageName(id: 6) == "HD60_512 Transfer.hda")
        #expect(BlueSCSI.imageName(id: 2) == "HD20_512 Transfer.hda")
        #expect(BlueSCSI.defaultID == 6)
        for id in BlueSCSI.validIDs {
            let name = BlueSCSI.imageName(id: id)
            #expect(name.count <= 64)
            #expect(BlueSCSI.parse(name)! == (id, 0, 512), "\(name)")
        }
    }

    /// The examples in BlueSCSI's own documentation.
    @Test func readsNamesAsBlueSCSIDoes() {
        #expect(BlueSCSI.parse("HD10_512.hda")! == (1, 0, 512))
        #expect(BlueSCSI.parse("HD50_512 System 6.0.8L LC.hda")! == (5, 0, 512))
        #expect(BlueSCSI.parse("HD6 - System 7 Quadra 700.hda")! == (6, 0, 512))
        #expect(BlueSCSI.parse("HD99_712 foo bar fizz buzz buzz buzz foo bar fizz buzz bang.hda") == nil)
        #expect(BlueSCSI.parse("CD3 Myst.iso") == nil)
        #expect(BlueSCSI.parse("Transfer.hda") == nil)
    }

    @Test func ids() {
        #expect(BlueSCSI.check(id: 6) == nil && BlueSCSI.check(id: 0) == nil)
        #expect(BlueSCSI.check(id: 7) == .idOutOfRange(7))
        #expect(BlueSCSI.check(id: -1) == .idOutOfRange(-1))
        #expect(BlueSCSI.warnings(id: 0).first?.contains("boot disk") == true)
        #expect(BlueSCSI.warnings(id: 6).count == 1)
    }
}

/// Comparing the tuples above.
func == (a: (id: Int, lun: Int, sectorSize: Int), b: (Int, Int, Int)) -> Bool {
    a.id == b.0 && a.lun == b.1 && a.sectorSize == b.2
}
