import SwiftUI
import UniformTypeIdentifiers
import MacintoshTransferKit

struct MainWindowView: View {
    @Bindable var model: AppModel
    @State private var dropTargeted = false
    @State private var showHow = false
    @State private var showChecks = false
    @State private var showAdvanced = false

    var body: some View {
        VStack(spacing: 0) {
            Form {
                filesSection
                diskSection
                folderSection
                advancedSection
                if model.result != nil || model.failure != nil { resultSection }
            }
            .formStyle(.grouped)
            .disabled(model.running)
            Divider()
            actionBar
        }
        .frame(minWidth: 680, minHeight: 600)
        .dropDestination(for: URL.self) { urls, _ in
            guard !model.running else { return false }
            model.add(urls)
            return true
        } isTargeted: { dropTargeted = $0 }
        .overlay {
            if dropTargeted { RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor, lineWidth: 3).padding(6) }
        }
        .alert("ID 0 is your boot disk's", isPresented: $model.askBootID) {
            Button("Use ID 0 Anyway", role: .destructive) { model.bootIDConfirmed() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("An image with ID 0 would clash with the disk your Macintosh Plus starts up from. Choose another ID unless you mean to replace it on the card.")
        }
        .alert("“\(model.existingName)” is already in “\(model.prefs.folder.lastPathComponent)”", isPresented: $model.askExisting) {
            Button("Keep Both") { model.existingAnswered(.keepBoth) }.keyboardShortcut(.defaultAction)
            Button("Replace", role: .destructive) { model.existingAnswered(.replace) }
            Button("Cancel", role: .cancel) { model.existingAnswered(nil) }
        } message: {
            Text("Keep Both saves the new one as “… Transfer 2.hda”. Both would use SCSI ID \(model.prefs.scsiID), so put only one of them on the card.")
        }
    }

    // MARK: Files

    var filesSection: some View {
        Section {
            if model.queue.files.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "waveform.badge.plus").font(.system(size: 30)).foregroundStyle(.tertiary)
                    Text("Drop MacMusic WAV files here, or a folder of them.").foregroundStyle(.secondary)
                    Button("Add Files…") { model.addFiles() }
                }
                .frame(maxWidth: .infinity, minHeight: 130)
            } else {
                Table(model.queue.files, selection: $model.selection) {
                    TableColumn("File") { f in Text(f.source.lastPathComponent).lineLimit(1).truncationMode(.middle) }
                    TableColumn("On the Mac") { f in
                        Text(f.macName.isEmpty ? "—" : f.macName)
                            .foregroundStyle(f.renamed ? Color.orange : Color.primary)
                            .help(f.renamed ? "Renamed to suit the Mac." : "")
                    }
                    TableColumn("Format") { f in Text(format(f)).foregroundStyle(.secondary).lineLimit(1) }
                        .width(min: 96, ideal: 128, max: 150)
                    TableColumn("Length") { f in Text(f.duration.map(length) ?? "").monospacedDigit() }.width(54)
                    TableColumn("Size") { f in Text(bytes(f.size)).monospacedDigit() }.width(64)
                    TableColumn("Status") { f in
                        if let p = f.problem {
                            Label("Can't be used", systemImage: "xmark.octagon.fill").foregroundStyle(.red).help(p)
                        } else {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        }
                    }.width(96)
                }
                .frame(minHeight: 200)
                .onDeleteCommand { model.removeSelected() }
                HStack {
                    Button("Add Files…") { model.addFiles() }
                    Button("Remove") { model.removeSelected() }.disabled(model.selection.isEmpty)
                    Button("Clear All") { model.clearAll() }
                    Spacer()
                    Text(totals).font(.callout).foregroundStyle(.secondary).monospacedDigit()
                }
                ForEach(model.queue.refused) { f in
                    Label("\(f.source.lastPathComponent): \(f.problem ?? "")", systemImage: "xmark.octagon")
                        .font(.callout).foregroundStyle(.red)
                }
            }
            ForEach(model.queue.notes, id: \.self) { n in
                Label(n, systemImage: "info.circle").font(.callout).foregroundStyle(.secondary)
            }
        } header: {
            Text("Files")
        }
    }

    var totals: String {
        let q = model.queue
        let playing = q.hasDurations ? " · \(length(q.totalSeconds))" : ""
        return "\(q.files.count) file\(q.files.count == 1 ? "" : "s")\(playing) · \(bytes(q.totalBytes))"
    }

    // MARK: The disk

    var diskSection: some View {
        Section("Disk") {
            Picker("SCSI ID", selection: $model.prefs.scsiID) {
                ForEach(Array(BlueSCSI.validIDs), id: \.self) { id in
                    Text(id == BlueSCSI.bootID ? "\(id) (your boot disk)" : "\(id)").tag(id)
                }
            }
            LabeledContent("File name") { Text(model.imageName).textSelection(.enabled) }
            ForEach(BlueSCSI.warnings(id: model.prefs.scsiID), id: \.self) { w in
                Label(w, systemImage: model.prefs.scsiID == BlueSCSI.bootID && w.contains("boot")
                      ? "exclamationmark.triangle.fill" : "info.circle")
                    .font(.callout)
                    .foregroundStyle(model.prefs.scsiID == BlueSCSI.bootID && w.contains("boot") ? Color.orange : Color.secondary)
            }
            LabeledContent("Volume", value: "“\(Layout.volumeName)”, its files in \(folderWords)")
            LabeledContent("Size") {
                Text(model.queue.ready.isEmpty ? "—" : "about \(sizeText(model.job.imageBytes))")
            }
            if !model.queue.ready.isEmpty {
                DisclosureGroup("How is this worked out?", isExpanded: $showHow) {
                    Text(model.job.sizeExplanation).font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.callout)
            }
        }
    }

    var folderSection: some View {
        Section("Save To") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.prefs.folder.lastPathComponent).font(.headline)
                    Text(model.prefs.folder.deletingLastPathComponent().path)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                if model.prefs.folderPath != nil { Button("Use Default") { model.useDefaultFolder() } }
                Button("Choose…") { model.chooseFolder() }
            }
        }
    }

    var advancedSection: some View {
        Section {
            DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
                LabeledContent("Disk template") {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(model.prefs.template.lastPathComponent).lineLimit(1).truncationMode(.middle)
                        Text(model.templateStatus).font(.caption)
                            .foregroundStyle(model.templateOK ? Color.secondary : Color.red)
                    }
                }
                HStack {
                    Text("Its partition map and Apple Driver 4.3 start every disk this app makes.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if model.prefs.templatePath != nil { Button("Use Default") { model.useDefaultTemplate() } }
                    Button("Choose…") { model.chooseTemplate() }
                }
            }
        }
    }

    // MARK: The result

    var resultSection: some View {
        Section("Result") {
            if let failure = model.failure {
                Label(failure, systemImage: "xmark.octagon.fill").foregroundStyle(.red)
            }
            if let r = model.result {
                HStack(alignment: .firstTextBaseline) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.image.lastPathComponent).font(.headline)
                        Text("\(r.files.count) file\(r.files.count == 1 ? "" : "s") · \(sizeText(r.imageBytes)) · "
                             + "\(bytes(r.freeBytes)) free on it · verified")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Copy Summary") { model.copySummary() }
                    Button("Show in Finder") { model.show(r.image) }
                }
                Label("Copy it to the root of the BlueSCSI's SD card with the Finder. No other image on the card should use SCSI ID \(r.scsiID).",
                      systemImage: "sdcard")
                    .font(.callout).foregroundStyle(.secondary)
                ForEach(r.warnings.filter { !$0.contains("one image per SCSI ID") }, id: \.self) { w in
                    Label(w, systemImage: "exclamationmark.triangle").font(.callout).foregroundStyle(.orange)
                }
                DisclosureGroup("What was checked", isExpanded: $showChecks) {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(r.checks, id: \.self) { c in
                            Label(c, systemImage: "checkmark").font(.caption)
                        }
                        ForEach(r.files.filter { $0.source.lastPathComponent != $0.macName }, id: \.macName) { f in
                            Text("\(f.source.lastPathComponent) → \(f.macName)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.callout)
            }
        }
    }

    var actionBar: some View {
        HStack(spacing: 12) {
            if model.running, let p = model.progress {
                VStack(alignment: .leading, spacing: 4) {
                    Text(p.stage.rawValue + (p.detail.map { ": \($0)" } ?? "") + "…").font(.callout).lineLimit(1)
                    if let f = p.fraction { ProgressView(value: f) } else { ProgressView().progressViewStyle(.linear) }
                }
                Button("Cancel") { model.cancel() }.keyboardShortcut(.cancelAction)
            } else {
                if !model.templateOK {
                    Label("The disk template can't be used (Advanced).", systemImage: "xmark.octagon").foregroundStyle(.red)
                }
                Spacer()
                Button("Build Transfer Image") { model.build() }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
                    .disabled(!model.canBuild)
            }
        }
        .padding(16)
    }

    // MARK: Words

    /// The folders the image will hold: those of the files ready, or, with
    /// none yet, every kind's.
    var folderWords: String {
        let folders = model.queue.folders.isEmpty ? FileKind.allCases.map(\.folder) : model.queue.folders
        return (folders.count == 1 ? "the folder " : "the folders ") + folders.map { "“\($0)”" }.joined(separator: ", ")
    }

    func format(_ f: QueuedFile) -> String {
        guard case .wav(let r) = f.details else { return "unknown kind" }
        let ch = r.channels == 1 ? "mono" : r.channels == 2 ? "stereo" : "\(r.channels) ch"
        // Compact, and still exact: "22.05 kHz mono 8-bit" (the owner's
        // screenshots: the full form left too little room for the names).
        let khz = (Double(r.sampleRate) / 1000).formatted(.number.precision(.fractionLength(0...3)))
        return "\(khz) kHz \(ch) \(r.bitsPerSample)-bit"
    }
}

func length(_ seconds: Double) -> String {
    let s = Int(seconds.rounded())
    return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
}

func bytes(_ n: Int) -> String { ByteCountFormatter.string(fromByteCount: Int64(n), countStyle: .file) }
