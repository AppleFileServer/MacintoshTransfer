import Foundation
import MacintoshTransferKit

// mtu-build: builds a Transfer image from WAV files with the engine (a
// developer's tool until the app does it). Names are made to suit the Mac;
// an existing image is kept, the new one named "... Transfer 2.hda".
//
//   mtu-build [--id N] [--replace] <output folder> <file.wav> ...

var args = Array(CommandLine.arguments.dropFirst())
var id = BlueSCSI.defaultID
var existing = ExistingImage.keepBoth
if let i = args.firstIndex(of: "--id"), i + 1 < args.count, let n = Int(args[i + 1]) {
    id = n
    args.removeSubrange(i...(i + 1))
}
if let i = args.firstIndex(of: "--replace") { existing = .replace; args.remove(at: i) }
guard args.count >= 2 else {
    FileHandle.standardError.write(Data("usage: mtu-build [--id N] [--replace] <output folder> <file.wav> ...\n".utf8))
    exit(2)
}

var queue = Queue()
queue.add(args.dropFirst().map { URL(fileURLWithPath: $0) })
for n in queue.notes { print("note  \(n)") }
for f in queue.files {
    let to = f.renamed ? "  → \(f.macName)" : ""            // refused files have no Mac name
    print("\(f.problem == nil ? "ok  " : "NO  ")  \(f.source.lastPathComponent)\(to): \(f.description)")
    if let p = f.problem { print("      \(p)") }
}
let job = TransferJob(queue: queue, folder: URL(fileURLWithPath: args[0]), scsiID: id, existing: existing)
print("size  \(job.sizeExplanation)")
do {
    let result = try await TransferEngine().run(job) { p in
        print("  \(p.stage.rawValue)" + (p.detail.map { ": \($0)" } ?? ""))
    }
    print(result.summary)
} catch let e as TransferError {
    FileHandle.standardError.write(Data("mtu-build: \(e.message)\n".utf8))
    exit(1)
}
