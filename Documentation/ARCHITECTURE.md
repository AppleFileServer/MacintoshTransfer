# Architecture

## The image (decisions Q2, Q10)

    HD60_512 Transfer.hda                 a BlueSCSI device image, 512-byte blocks
      block 0       driver descriptor     from the template; the disk's size set
      blocks 1-63   Apple partition map   from the template; Apple_HFS made to reach the end
      blocks 64-95  Apple Driver 4.3      from the template, unchanged
      block 96-     HFS volume "Transfer" made by hfsutils
                      WAV Files/          the WAVs, data forks only, WAVE/????
                                          (a folder per kind present, M11, K5)

## The package

| Target / file | What |
|---|---|
| `BlueSCSI` | names (`HD60_512 Transfer.hda`), IDs, warnings; reading a name as BlueSCSI does |
| `PartitionTemplate` | loading and checking a template; its 96 blocks sized for a disk |
| `HFSUtils`, `RawSpawn` | hfsutils with a private HOME; arguments as exact bytes (HFS paths in Mac Roman) |
| `FileKind`, `FileDetails` | the kinds of file (M9, K1): each one's folder, type, creator, Mac extension, hints, content check and words; what its validator found. T2: the WAV only |
| `ImageBuilder`, `Layout`, `Sizing` | the image: header, `hformat` in place, a folder per kind present, the files with their kind's type and creator; the sizing policy (Q6) |
| `HFSReader` | an independent, read-only HFS reader (Inside Macintosh: Files) |
| `ImageVerifier` | the checks: the map and driver against the template, the volume, only the folders used, each holding exactly its files, each file's size, SHA-256, type and creator |
| `MacMusicWAVValidator`, `WAVFile`, `MacMusicFormat`, `MacMusicText` | the converter's copies of MacMusic's `wav.c` rules (V1) |
| `Queue`, `QueuedFile`, `MacNames` | the queue: each file's kind by its content, read and checked, its Mac name, clashes within a folder, duplicates (V1-V3, K2-K4) |
| `TransferJob`, `TransferEngine` | the job and the engine: stages, the temporary image, verification, the move, an existing image, cancelling (V4-V7) |
| `ProcessRunner` | from the converter (with an environment); for other tools |
| `mtu-build` | the developer's tool: builds and verifies an image |
| `MacintoshTransferKitTests` | the tests |
| `Preferences` | the folder, the ID, the template (U7); 1.0's settings carried over, the default folder (M4, M5) |
| `MacintoshTransfer` (the app) | `AppModel` (state, the build task, the questions), `MainWindowView`, `AppDelegate` and `WindowFinder` (from the converter: asking before quitting mid-build) |
