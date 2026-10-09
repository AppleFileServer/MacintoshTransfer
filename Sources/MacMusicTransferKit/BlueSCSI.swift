import Foundation

/// BlueSCSI's naming and IDs (SPECIFICATION.md §15.1; decisions Q9, Q10).
/// From bluescsi.com/docs ("Usage", read 2026-10-09): `HDxy_512 <text>.hda`,
/// x the SCSI ID, y an optional LUN (0 only), 512 the sector size, the text
/// after it ignored, at most 64 characters.
public enum BlueSCSI {
    public static let defaultID = 6                      // the owner's choice (Q9)
    public static let validIDs = 0...6                   // 7 is the Mac itself
    public static let bootID = 0                         // the owner's boot disk
    public static let maximumNameLength = 64
    public static let sectorSize = 512

    /// "HD60_512 Transfer.hda": an explicit LUN 0, as the proven HD50_512.
    public static func imageName(id: Int, label: String = "Transfer") -> String {
        "HD\(id)0_\(sectorSize) \(label).hda"
    }

    public enum Problem: Error, Equatable, Sendable {
        case idOutOfRange(Int)
        case nameTooLong(Int)
        case notAHardDiskName
    }

    /// What's wrong with an ID, if anything.
    public static func check(id: Int) -> Problem? {
        validIDs.contains(id) ? nil : .idOutOfRange(id)
    }

    /// Warnings worth showing for an ID (not errors).
    public static func warnings(id: Int) -> [String] {
        var w = ["BlueSCSI uses one image per SCSI ID: make sure no other image on the card uses ID \(id)."]
        if id == bootID {
            w.insert("ID 0 is your boot disk's: an image here would clash with it.", at: 0)
        }
        return w
    }

    /// Reads a hard disk image's name as BlueSCSI does: the ID, the LUN, the
    /// sector size. Nil if it isn't a valid hard disk name.
    public static func parse(_ name: String) -> (id: Int, lun: Int, sectorSize: Int)? {
        guard name.count <= maximumNameLength, name.lowercased().hasSuffix(".hda"), name.hasPrefix("HD") else { return nil }
        let rest = Array(name.dropFirst(2))
        guard let first = rest.first, let id = first.wholeNumberValue, validIDs.contains(id) || id == 7 else { return nil }
        var i = 1, lun = 0
        if i < rest.count, let l = rest[i].wholeNumberValue { lun = l; i += 1 }
        guard lun == 0 else { return nil }
        var size = 512
        if i < rest.count, rest[i] == "_" {
            let digits = rest[(i + 1)...].prefix { $0.isNumber }
            guard let s = Int(String(digits)) else { return nil }
            size = s
        }
        return (id, lun, size)
    }
}
