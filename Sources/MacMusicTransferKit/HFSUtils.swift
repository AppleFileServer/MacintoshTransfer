import Foundation

/// hfsutils (decision Q4): Retro68's build in development; inside the app
/// from Stage 5. Each job runs them with its own HOME, a temporary folder,
/// because they keep their "current volume" in ~/.hcwd: two jobs, or the
/// user's own hfsutils, can't then get in each other's way.
public struct HFSUtils: Sendable {
    public let folder: URL
    let home: URL

    public enum Problem: Error, Equatable, Sendable {
        case notFound([String])
        case failed(command: String, message: String)
        /// A name the classic Mac can't hold (not Mac Roman).
        case notMacRoman(String)
    }

    /// An argument: a path on this Mac (UTF-8), or a path on the HFS volume
    /// (Mac Roman, the Mac's own encoding).
    public enum Argument: Sendable {
        case option(String)
        case hostPath(String)
        case hfsPath(String)

        func bytes() throws -> [UInt8] {
            switch self {
            case .option(let s), .hostPath(let s): return Array(s.utf8)
            case .hfsPath(let s):
                guard let d = s.precomposedStringWithCanonicalMapping.data(using: .macOSRoman) else {
                    throw Problem.notMacRoman(s)
                }
                return [UInt8](d)
            }
        }
    }

    public static let developmentFolder = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Retro68-build/toolchain/bin")

    public static let needed = ["hformat", "hmount", "humount", "hmkdir", "hcopy", "hattrib", "hls", "hvol"]

    /// Finds hfsutils (MTU_HFSUTILS, the app's Contents/Helpers, Retro68's
    /// build), with `home` as its private HOME.
    public static func locate(home: URL, environment: [String: String] = ProcessInfo.processInfo.environment,
                              helpers: URL? = nil) throws -> HFSUtils {
        var folders: [URL] = []
        if let named = environment["MTU_HFSUTILS"], !named.isEmpty { folders.append(URL(fileURLWithPath: named)) }
        if let helpers { folders.append(helpers) }
        folders.append(developmentFolder)
        for f in folders where needed.allSatisfy({ FileManager.default.isExecutableFile(atPath: f.appendingPathComponent($0).path) }) {
            return HFSUtils(folder: f, home: home)
        }
        throw Problem.notFound(folders.map(\.path))
    }

    /// Runs one hfsutils command, its arguments as exact bytes (RawSpawn);
    /// its standard output, read as Mac Roman.
    @discardableResult
    public func run(_ command: String, _ arguments: [Argument]) async throws -> String {
        let r = try await RawSpawn.run(folder.appendingPathComponent(command), try arguments.map { try $0.bytes() },
                                       environment: ["HOME": home.path, "PATH": "/usr/bin:/bin", "LANG": "C"])
        guard r.status == 0 else {
            throw Problem.failed(command: command,
                                 message: (String(data: r.stderr, encoding: .macOSRoman) ?? "")
                                    .trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return String(data: r.stdout, encoding: .macOSRoman) ?? ""
    }
}
