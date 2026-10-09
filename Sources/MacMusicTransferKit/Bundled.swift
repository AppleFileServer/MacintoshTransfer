import Foundation

/// What the packaged app carries inside it (Stage 5; R1-R3): hfsutils in
/// Contents/Helpers/hfsutils and the template in Contents/Resources. The
/// packaged app uses only these (a release is self-contained); run from
/// the repository, the development copies are used instead.
public enum Bundled {
    /// Running as the packaged app, not from the repository.
    public static var isApp: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    public static var helpers: URL? {
        isApp ? Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/hfsutils") : nil
    }

    public static var template: URL? {
        isApp ? Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/bluescsi-template.hda") : nil
    }
}
