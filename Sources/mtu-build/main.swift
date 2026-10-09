import Foundation
import MacMusicTransferKit

// mtu-build: builds a Transfer image from WAV files (Stage 1's proof; a
// developer's tool until the app does it). The files keep their own names,
// which must already suit the Mac (at most 31 characters, no colon): Stage
// 2 adds the naming rules.
//
//   mtu-build [--id N] <output folder> <file.wav> ...

var args = Array(CommandLine.arguments.dropFirst())
var id = BlueSCSI.defaultID
if let i = args.firstIndex(of: "--id"), i + 1 < args.count, let n = Int(args[i + 1]) {
    id = n
    args.removeSubrange(i...(i + 1))
}
guard args.count >= 2 else {
    FileHandle.standardError.write(Data("usage: mtu-build [--id N] <output folder> <file.wav> ...\n".utf8))
    exit(2)
}
if let problem = BlueSCSI.check(id: id) { FileHandle.standardError.write(Data("mtu-build: \(problem)\n".utf8)); exit(2) }
let folder = URL(fileURLWithPath: args[0])
let files = args.dropFirst().map { ImageFile(source: URL(fileURLWithPath: $0), macName: URL(fileURLWithPath: $0).lastPathComponent) }
for f in files where f.macName.count > 31 || f.macName.contains(":") {
    FileHandle.standardError.write(Data("mtu-build: \"\(f.macName)\" doesn't suit the Mac (at most 31 characters, no colon)\n".utf8))
    exit(2)
}

let output = folder.appendingPathComponent(BlueSCSI.imageName(id: id))
guard !FileManager.default.fileExists(atPath: output.path) else {
    FileHandle.standardError.write(Data("mtu-build: \(output.path) already exists\n".utf8))
    exit(1)
}
let work = FileManager.default.temporaryDirectory.appendingPathComponent("mtu-build-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: work) }

do {
    let template = try PartitionTemplate.load(PartitionTemplate.archived)
    let hfs = try HFSUtils.locate(home: work)
    let total = try files.reduce(0) { $0 + ((try FileManager.default.attributesOfItem(atPath: $1.source.path)[.size] as? Int) ?? 0) }
    let bytes = Sizing.imageBytes(forFiles: total)
    let temporary = folder.appendingPathComponent(".mtu-\(UUID().uuidString).hda.partial")
    defer { try? FileManager.default.removeItem(at: temporary) }
    try await ImageBuilder(template: template, hfsutils: hfs).build(files, imageBytes: bytes, to: temporary)
    let report = ImageVerifier.verify(temporary, files: files, template: template)
    for c in report.checks { print("ok    \(c)") }
    for p in report.problems { print("FAIL  \(p)") }
    guard report.passed else { exit(1) }
    try FileManager.default.moveItem(at: temporary, to: output)
    print("made  \(output.path): \(bytes / 1_048_576) MB, ID \(id), \(files.count) file(s)")
    for w in BlueSCSI.warnings(id: id) { print("note  \(w)") }
} catch {
    FileHandle.standardError.write(Data("mtu-build: \(error)\n".utf8))
    exit(1)
}
