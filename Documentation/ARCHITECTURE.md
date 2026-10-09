# Architecture

## The image (decisions Q2, Q10)

    HD60_512 Transfer.hda                 a BlueSCSI device image, 512-byte blocks
      block 0       driver descriptor     from the template; the disk's size set
      blocks 1-63   Apple partition map   from the template; Apple_HFS made to reach the end
      blocks 64-95  Apple Driver 4.3      from the template, unchanged
      block 96-     HFS volume "Transfer" made by hfsutils
                      WAV Files/          the WAVs, data forks only, type WAVE

## The package

| Target / file | What |
|---|---|
| `BlueSCSI` | names (`HD60_512 Transfer.hda`), IDs, warnings; reading a name as BlueSCSI does |
| `PartitionTemplate` | loading and checking a template; its 96 blocks sized for a disk |
| `HFSUtils`, `RawSpawn` | hfsutils with a private HOME; arguments as exact bytes (HFS paths in Mac Roman) |
| `ImageBuilder`, `Layout`, `Sizing` | the image: header, `hformat` in place, the folder, the files; the sizing policy (Q6) |
| `HFSReader` | an independent, read-only HFS reader (Inside Macintosh: Files) |
| `ImageVerifier` | the checks: the map and driver against the template, the volume, the folder, each file's size and SHA-256 |
| `ProcessRunner` | from the converter (with an environment); for other tools |
| `mtu-build` | the developer's tool: builds and verifies an image |
| `MacMusicTransferKitTests` | the tests |
| (Stage 3) `MacMusicTransfer` | the SwiftUI app |
