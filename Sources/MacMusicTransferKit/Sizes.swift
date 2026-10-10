import Foundation

/// A size as the Finder shows it (decimal megabytes: "46.1 MB"), so the
/// app and the Finder always agree (the owner's choice, 2026-10-10). The
/// disk's own size is still worked out in whole binary megabytes, as disk
/// geometry is (ImageBuilder.Sizing); only what's shown is the Finder's.
public func sizeText(_ bytes: Int) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
}
