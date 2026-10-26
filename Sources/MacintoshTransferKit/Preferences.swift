import Foundation

/// What the app remembers (U7): the save folder, the SCSI ID, the
/// template. Not the list of files.
public struct Preferences: Codable, Sendable, Equatable {
    public var folderPath: String?
    public var scsiID = BlueSCSI.defaultID
    /// Another template chosen (U8); nil for the default.
    public var templatePath: String?

    public init() {}

    /// `~/Documents/Macintosh Transfer` (U2, M5), made when first used; but
    /// 1.0's `~/Music/MacMusic Transfer` if it's there, so nothing moves.
    public static var defaultFolder: URL { defaultFolder(home: FileManager.default.homeDirectoryForCurrentUser) }

    static func defaultFolder(home: URL) -> URL {
        let old = home.appendingPathComponent("Music/MacMusic Transfer", isDirectory: true)
        var isFolder: ObjCBool = false
        if FileManager.default.fileExists(atPath: old.path, isDirectory: &isFolder), isFolder.boolValue { return old }
        return home.appendingPathComponent("Documents/Macintosh Transfer", isDirectory: true)
    }

    public var folder: URL { folderPath.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? Self.defaultFolder }

    public var template: URL { templatePath.map { URL(fileURLWithPath: $0) } ?? PartitionTemplate.standard }

    static let key = "MacintoshTransferUtility.preferences"
    /// 1.0's key (M4): copied to the new one the first time, and left for 1.0.
    static let oldKey = "MacMusicTransferUtility.preferences"

    public static func load(from defaults: UserDefaults = .standard) -> Preferences {
        if defaults.data(forKey: key) == nil, let old = defaults.data(forKey: oldKey) {
            defaults.set(old, forKey: key)
        }
        guard let data = defaults.data(forKey: key),
              var p = try? JSONDecoder().decode(Preferences.self, from: data) else { return Preferences() }
        if BlueSCSI.check(id: p.scsiID) != nil { p.scsiID = BlueSCSI.defaultID }
        return p
    }

    public func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.key) }
    }
}
