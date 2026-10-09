import AppKit
import Observation
import MacMusicTransferKit

/// The window's state, and the running build. Its decisions (the queue,
/// names, the job, preferences) live in the engine library, where they're
/// tested (U9); this wires them to the window.
@MainActor @Observable
final class AppModel {
    var queue = Queue()
    var selection = Set<URL>()
    var prefs = Preferences.load() { didSet { prefs.save() } }

    var running = false
    var progress: TransferProgress?
    var result: TransferResult?
    var failure: String?
    private var task: Task<Void, Never>?

    // Questions before building (U3, U4).
    var askExisting = false
    var askBootID = false
    var existingName = ""

    // The template (U8).
    var templateStatus: String {
        do {
            let t = try PartitionTemplate.load(prefs.template)
            let names = t.entries.map(\.type).joined(separator: ", ")
            return "OK: \(names)"
        } catch {
            return "Can't be used: \(error)"
        }
    }
    var templateOK: Bool { (try? PartitionTemplate.load(prefs.template)) != nil }

    init() {
        // What a crash may have left (L3): ours only, over an hour old.
        let folders = [prefs.folder, FileManager.default.temporaryDirectory]
        Task.detached(priority: .utility) { Leftovers.clean(folders) }
    }

    var job: TransferJob {
        TransferJob(queue: queue, folder: prefs.folder, scsiID: prefs.scsiID, template: prefs.template)
    }
    var imageName: String { BlueSCSI.imageName(id: prefs.scsiID) }
    var canBuild: Bool { !running && queue.canBuild && templateOK }

    // MARK: The files

    func addFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.allowedContentTypes = [.wav, .folder]
        panel.message = "Choose WAV files, or a folder of them (its WAVs, not those in folders within)."
        panel.prompt = "Add"
        if panel.runModal() == .OK { add(panel.urls) }
    }

    func add(_ urls: [URL]) {
        guard !running else { return }
        queue.add(urls)
        result = nil
        failure = nil
    }

    func removeSelected() {
        guard !running, !selection.isEmpty else { return }
        queue.remove(selection)
        selection = []
        result = nil
    }

    func clearAll() {
        guard !running else { return }
        queue.clear()
        selection = []
        result = nil
        failure = nil
    }

    // MARK: Building

    func build() {
        guard canBuild else { return }
        if prefs.scsiID == BlueSCSI.bootID {
            askBootID = true
        } else {
            checkExisting()
        }
    }

    func bootIDConfirmed() { checkExisting() }

    private func checkExisting() {
        if !makeFolder() { return }
        let url = prefs.folder.appendingPathComponent(imageName)
        if FileManager.default.fileExists(atPath: url.path) {
            existingName = imageName
            askExisting = true
        } else {
            start(.refuse)
        }
    }

    func existingAnswered(_ choice: ExistingImage?) {
        if let choice { start(choice) }
    }

    private func makeFolder() -> Bool {
        do {
            try FileManager.default.createDirectory(at: prefs.folder, withIntermediateDirectories: true)
            return true
        } catch {
            failure = TransferError.destinationUnavailable(prefs.folder.path).message
            return false
        }
    }

    private func start(_ existing: ExistingImage) {
        var job = self.job
        job.existing = existing
        running = true
        result = nil
        failure = nil
        progress = TransferProgress(stage: .checking, detail: nil, fraction: nil)
        task = Task {
            do {
                result = try await TransferEngine().run(job) { p in
                    Task { @MainActor in if self.running { self.progress = p } }
                }
            } catch let e as TransferError {
                failure = (progress.map { "\($0.stage.rawValue) failed. " } ?? "") + e.message
                if case .cancelled = e { failure = e.message }
            } catch {
                failure = "Something went wrong: \(error)"
            }
            running = false
            progress = nil
            task = nil
        }
    }

    func cancel() { task?.cancel() }

    // MARK: Folders and the template

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.directoryURL = prefs.folder
        panel.message = "Choose where to save the disk image."
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url { prefs.folderPath = url.path }
    }

    func useDefaultFolder() { prefs.folderPath = nil }

    func chooseTemplate() {
        let panel = NSOpenPanel()
        panel.message = "Choose a BlueSCSI hard disk image that works on your Mac Plus: its partition map and Apple Driver 4.3 are used."
        panel.prompt = "Use"
        if panel.runModal() == .OK, let url = panel.url { prefs.templatePath = url.path }
    }

    func useDefaultTemplate() { prefs.templatePath = nil }

    func show(_ url: URL) { NSWorkspace.shared.activateFileViewerSelecting([url]) }

    func copySummary() {
        guard let result else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result.summary, forType: .string)
    }
}
