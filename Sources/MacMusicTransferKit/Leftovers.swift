import Foundation

/// What a crash or a power cut can leave (Stage 4; L3): the app's own
/// temporary files, recognised by their names, removed at launch once
/// they're over an hour old (so a build still running in another copy of
/// the app is left alone). As the MacMusic Converter Utility does (its H1).
public enum Leftovers {
    public static let minimumAge: TimeInterval = 3_600

    /// ".mtu-<uuid>.hda.partial" in a save folder; "mtu-job-…",
    /// "mtu-spawn-…", "mtu-build-…" in the temporary folder.
    public static func isOurs(_ name: String) -> Bool {
        (name.hasPrefix(".mtu-") && name.hasSuffix(".partial"))
            || ["mtu-job-", "mtu-spawn-", "mtu-build-"].contains { name.hasPrefix($0) }
    }

    @discardableResult
    public static func clean(_ folders: [URL], now: Date = Date()) -> [URL] {
        let files = FileManager.default
        var removed: [URL] = []
        for folder in folders {
            guard let items = try? files.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: [.contentModificationDateKey], options: []) else { continue }
            for item in items where isOurs(item.lastPathComponent) {
                let changed = (try? item.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? now
                if now.timeIntervalSince(changed) >= minimumAge, (try? files.removeItem(at: item)) != nil {
                    removed.append(item)
                }
            }
        }
        return removed
    }
}
