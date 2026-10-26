import Darwin
import Foundation

/// Starts a program with its arguments as exact bytes (posix_spawn), not
/// as UTF-8 text as Foundation's Process does. hfsutils stores a name as
/// the bytes it's given, and the classic Mac reads names as Mac Roman, so
/// "Café" must reach it as 43 61 66 8E, not UTF-8's (decomposed) bytes.
/// Standard output and error go to temporary files; cancelling the task
/// stops the program.
enum RawSpawn {
    struct Result { let status: Int32; let stdout: Data; let stderr: Data }

    enum Problem: Error, Equatable, Sendable {
        case spawnFailed(Int32)
        case cancelled
    }

    static func run(_ executable: URL, _ arguments: [[UInt8]], environment: [String: String]) async throws -> Result {
        let files = FileManager.default
        let dir = files.temporaryDirectory.appendingPathComponent("mtu-spawn-\(UUID().uuidString)")
        try files.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: dir) }
        let outPath = dir.appendingPathComponent("stdout").path
        let errPath = dir.appendingPathComponent("stderr").path

        // C strings for argv and envp, freed when done.
        func cString(_ bytes: [UInt8]) -> UnsafeMutablePointer<CChar> {
            let p = UnsafeMutablePointer<CChar>.allocate(capacity: bytes.count + 1)
            for (i, b) in bytes.enumerated() { p[i] = CChar(bitPattern: b) }
            p[bytes.count] = 0
            return p
        }
        var argv: [UnsafeMutablePointer<CChar>?] = [cString(Array(executable.path.utf8))] + arguments.map(cString) + [nil]
        var envp: [UnsafeMutablePointer<CChar>?] = environment.map { cString(Array("\($0.key)=\($0.value)".utf8)) } + [nil]
        defer {
            for p in argv { p?.deallocate() }
            for p in envp { p?.deallocate() }
        }

        var actions = posix_spawn_file_actions_t(nil as OpaquePointer?)
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        posix_spawn_file_actions_addopen(&actions, 0, "/dev/null", O_RDONLY, 0)
        posix_spawn_file_actions_addopen(&actions, 1, outPath, O_WRONLY | O_CREAT | O_TRUNC, 0o600)
        posix_spawn_file_actions_addopen(&actions, 2, errPath, O_WRONLY | O_CREAT | O_TRUNC, 0o600)

        var pid: pid_t = 0
        let started = posix_spawn(&pid, executable.path, &actions, nil, &argv, &envp)
        guard started == 0 else { throw Problem.spawnFailed(started) }
        let child = pid                                     // a constant, for the closures below
        RunningTools.shared.add(child)
        defer { RunningTools.shared.remove(child) }
        let stopped = Flag()

        let raw: Int32 = await withTaskCancellationHandler {
            await withCheckedContinuation { (done: CheckedContinuation<Int32, Never>) in
                DispatchQueue.global(qos: .userInitiated).async {
                    var status: Int32 = 0
                    while waitpid(child, &status, 0) == -1 && errno == EINTR {}
                    done.resume(returning: status)
                }
            }
        } onCancel: {
            stopped.set()
            kill(child, SIGTERM)
        }
        if stopped.isSet { throw Problem.cancelled }
        // Exited normally: the exit code; killed by a signal: 128 + signal.
        let status = (raw & 0x7f) == 0 ? (raw >> 8) & 0xff : 128 + (raw & 0x7f)
        return Result(status: status,
                      stdout: (try? Data(contentsOf: URL(fileURLWithPath: outPath))) ?? Data(),
                      stderr: (try? Data(contentsOf: URL(fileURLWithPath: errPath))) ?? Data())
    }
}

final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var on = false
    func set() { lock.withLock { on = true } }
    var isSet: Bool { lock.withLock { on } }
}
