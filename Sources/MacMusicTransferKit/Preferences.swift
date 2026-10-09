import Foundation

/// What the app remembers (U7): the save folder, the SCSI ID, the
/// template. Not the list of files.
public struct Preferences: Codable, Sendable, Equatable {
    public var folderPath: String?
    public var scsiID = BlueSCSI.defaultID
    /// Another template chosen (U8); nil for the default.
    public var templatePath: String?

    public init() {}

    /// `~/Music/MacMusic Transfer` (U2), made when first used.
    public static var defaultFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Music/MacMusic Transfer", isDirectory: true)
    }

    public var folder: URL { folderPath.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? Self.defaultFolder }

    public var template: URL { templatePath.map { URL(fileURLWithPath: $0) } ?? PartitionTemplate.standard }

    static let key = "MacMusicTransferUtility.preferences"

    public static func load(from defaults: UserDefaults = .standard) -> Preferences {
        guard let data = defaults.data(forKey: key),
              var p = try? JSONDecoder().decode(Preferences.self, from: data) else { return Preferences() }
        if BlueSCSI.check(id: p.scsiID) != nil { p.scsiID = BlueSCSI.defaultID }
        return p
    }

    public func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.key) }
    }
}
