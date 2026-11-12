<!-- The owner's development brief (2026-10-09), kept word for word below
the line. Its working name "MacMusic Transfer" is the app's window title;
the app is the MacMusic Transfer Utility (Q1). Decisions and findings
since are in §15 at the end, not edited into the text. -->

---

# Claude Code Development Brief: MacMusic Transfer

## Project objective

Develop a native macOS application for Apple Silicon called **MacMusic Transfer**.

Its purpose is to take one or more WAV audio files produced by my existing audio-conversion application, package them into a classic Macintosh-compatible hard disk image, and produce a `.hda` file that I can copy to my BlueSCSI SD card and open on my physical Macintosh Plus running System 6.0.8.

The disk image should be called **Transfer** in the user interface and use a valid BlueSCSI-compatible filename, for example `HD2_512 Transfer.hda`.

The application must be reliable, safe and easy to use. It should automate the packaging process as much as possible, without requiring me to manually use Terminal, Disk Utility or another image-management application for routine transfers.

This is a separate utility within my wider MacMusic project. Do not merge it into the existing audio converter or modify the MacMusic Player unless explicitly instructed.

---

## 1. Begin by investigating the existing environment

Before writing implementation code:

1. Inspect the repository, its build system, existing documentation and any previous design decisions.
2. Confirm that the app will run natively on Apple Silicon macOS.
3. Identify the existing WAV converter's output format and locate any available specification for the MacMusic Player's expected audio format.
4. Investigate the tools available for creating and modifying Macintosh hard disk images on modern macOS.
5. Research the official BlueSCSI documentation, especially:

   * Image filename conventions and SCSI IDs.
   * The distinction between device images and volume images.
   * Requirements for Macintosh-compatible SCSI drivers and partition maps.
   * Classic HFS filesystem compatibility.
   * Recommended procedures for transferring files into image files.
6. Inspect whether any existing `.hda` images, blank disk templates, Retro68 project assets or HFS utilities are already available locally.
7. Establish the current build and test status before making changes.

Document the findings in the project README or an initial investigation report.

### Critical technical requirement

The output must be a **real Macintosh SCSI device image**, not merely an HFS volume image renamed with a `.hda` extension.

It must contain the structures needed for the BlueSCSI to present it as a hard disk that the Macintosh Plus can recognise and mount.

The target system is a physical Macintosh Plus running System 6.0.8. Do not assume that an image that mounts in a modern emulator or on macOS will necessarily work on this machine.

Do not proceed with a disk-image creation strategy until its compatibility implications are understood.

---

## 2. Define the disk image format and creation strategy

Investigate and select the safest practical way to create a valid output image.

Evaluate these approaches:

* Starting from a known-good, preformatted Macintosh-compatible `.hda` template and adding files to its HFS partition.
* Creating and formatting a new device image using appropriate tools.
* Using an existing, suitable command-line library or utility to manipulate the HFS filesystem within an image.

Prefer a reproducible, automated process that does not depend on a user manually operating a graphical utility for each transfer.

If creating a new image requires formatting or installing a compatible SCSI driver, establish how that process can be performed reliably. The Macintosh Plus is not compatible with every later Macintosh disk driver.

If modifying an existing image is the most reliable approach, support a user-selectable template and document how to prepare or replace it.

Do not silently use an incompatible image format or fabricate filesystem structures.

### Image defaults

Use these initial defaults, subject to the compatibility investigation:

* Image display name: `Transfer`
* Output extension: `.hda`
* Sector size: 512 bytes
* SCSI ID: configurable, with ID 2 as the initial default
* Filesystem: classic HFS, compatible with System 6.0.8
* Volume name: `Transfer`
* Internal destination folder: `WAV Files`
* Image size: chosen to accommodate the selected WAV files, filesystem overhead and reasonable future additions

The SCSI ID must be editable. Clearly warn the user if the chosen ID could conflict with another configured device or an existing image. Do not assume ID 2 is always available.

Use the correct BlueSCSI filename convention, including the device type, ID, sector size and `.hda` extension. Keep the full filename within BlueSCSI's documented length limit.

A possible filename is `HD2_512 Transfer.hda`. The actual output filename must reflect the selected SCSI ID.

Never use `Transfer.hda` alone unless the current BlueSCSI documentation explicitly confirms that it is valid for this use.

---

## 3. User interface and workflow

Create a straightforward native macOS interface using SwiftUI unless the existing project has a compelling reason to use another native framework.

The intended workflow is:

1. Launch MacMusic Transfer.
2. Add multiple WAV files using a file picker or drag and drop.
3. Review the queued files.
4. Remove unwanted files or clear the list.
5. Choose the destination folder for the resulting image.
6. Review the image name, SCSI ID and estimated required capacity.
7. Select **Build Transfer Image**.
8. The application validates the files, prepares the image, copies the audio into the correct HFS folder, verifies the result and reports completion.
9. The user copies the completed `.hda` file to the root of the BlueSCSI SD card and uses it with the Macintosh Plus.

### Main window

Include:

* A clear application title: MacMusic Transfer.
* An area to add WAV files.
* A table or list showing the queued files.
* File name, duration, sample rate, channel count, bit depth and file size where these can be reliably determined.
* A total duration and total input size.
* Remove-selected and clear-all controls.
* An output destination selector.
* An editable SCSI ID selector.
* An image filename preview that updates when the ID changes.
* An estimated image capacity.
* A progress indicator and status messages.
* A prominent build button.
* Clear success and failure messages.

The interface should remain responsive while the image is being built.

Prevent accidental duplicate queue entries or explain how duplicates are handled.

Do not add features unrelated to the core workflow at this stage.

---

## 4. WAV file validation

Accept multiple WAV files in a single job.

Validate each file before starting image construction. Determine its actual properties from its audio data and headers rather than relying on its filename.

Initially, the application should be able to recognise and report:

* WAV container validity.
* PCM encoding where applicable.
* Sample rate.
* Number of channels.
* Bit depth.
* Duration.
* File size.
* Truncated or corrupt input files.
* Unsupported encodings or formats.

The expected MacMusic audio format is currently understood to be uncompressed, mono, 22,050 Hz, 8-bit unsigned PCM in a WAV container. Verify this against the existing converter and MacMusic Player implementation before treating it as a definitive contract.

For this first version, do not silently re-encode files during packaging. If a file does not meet the expected format, explain the issue and direct the user to the existing converter.

The application must not modify, delete or overwrite the source WAV files.

If validation fails for one file, identify the specific file and reason. Let the user correct the problem before building the image.

---

## 5. Organising the contents of the image

The image must have a predictable and documented layout.

Use the following initial structure:

* HFS volume: `Transfer`
* Folder within the volume: `WAV Files`
* All selected WAV files copied into that folder

Preserve the audio content exactly. Do not change sample rates, bit depths, channels, encoding or audio levels during packaging.

### Macintosh filename compatibility

Modern macOS filenames may not be suitable for a classic Macintosh filesystem.

Implement a deliberate filename policy that considers:

* Classic HFS filename length restrictions.
* Characters that cannot be represented safely.
* Duplicate names after sanitisation or truncation.
* Case-insensitive filename collisions.
* Unicode characters and accents.
* The `.wav` extension.

Use a predictable, documented approach to sanitisation. Never silently overwrite two files that map to the same destination filename.

Where a name must be shortened or changed, show the user the proposed destination name before building the image. Provide a clear mapping between original and destination filenames in the job summary or log.

Keep the original audio content unchanged.

Do not create unnecessary metadata files, hidden files or modern macOS resource artefacts inside the classic HFS volume.

---

## 6. Image sizing and capacity

Calculate the minimum capacity needed for all selected WAV files, including filesystem overhead and reasonable headroom.

Use a practical minimum image size where appropriate and avoid creating excessively large images without justification.

The application should:

* Estimate the required capacity before building.
* Explain how the estimate was calculated.
* Avoid filesystem and partition-size limits.
* Confirm that all files fit before writing.
* Detect insufficient capacity before it causes a partially completed output.
* Allow the image-size policy to be changed in future without rewriting the whole application.

If a preformatted template is used, determine its actual usable capacity instead of assuming the file size equals available HFS space.

---

## 7. Build process, progress and error handling

Treat image creation as a multi-step job:

1. Validate the input list.
2. Resolve filename conflicts.
3. Select or create a compatible device image.
4. Prepare the HFS filesystem or working copy.
5. Create the destination folder if necessary.
6. Copy the selected WAV files into it.
7. Verify that every expected file exists and has the expected size.
8. Validate the final image as far as the available tools permit.
9. Write the completed image to its final destination.
10. Report success and show the output path.

Use a temporary working file so a failure does not leave a misleading, apparently complete `.hda` file.

Write the final output atomically where possible. If the destination already contains a file with the same name, ask the user before replacing it.

Show progress by meaningful stages, not an invented percentage. If exact progress cannot be measured, display the current operation and use an indeterminate progress indicator.

Handle cancellation safely. Clean up temporary files when possible, but never delete the original WAV files or a pre-existing completed image.

If a failure occurs, report the failed stage and useful diagnostic information. Do not claim success if image verification has not completed.

---

## 8. Verification and compatibility

Verification must go beyond checking that an output file exists.

Where the selected tools permit it, verify:

* The output has the expected BlueSCSI filename.
* The image has the correct device-image structure.
* The image has a valid partition map and appropriate Macintosh SCSI driver.
* The HFS volume can be recognised and inspected.
* The volume name is `Transfer`.
* The `WAV Files` directory exists.
* Every expected audio file is present.
* File sizes and file contents match the input files, using checksums where appropriate.
* The image does not exceed its declared capacity or violate filesystem constraints.

Use independent verification where practical rather than relying entirely on the same operation that wrote the image.

### Physical-machine acceptance test

The final acceptance test must be performed on the actual Macintosh Plus running System 6.0.8, using the BlueSCSI hardware.

The test procedure should confirm that:

1. The `.hda` file is copied to the root of the BlueSCSI SD card.
2. Its SCSI ID does not conflict with the boot disk or another device.
3. The Macintosh Plus recognises and mounts the disk.
4. The volume appears as `Transfer`.
5. The `WAV Files` folder opens and contains all selected files.
6. The files can be opened or imported by the intended MacMusic workflow.
7. The audio files remain intact.

Automated tests cannot substitute for this physical-machine test. If Claude Code cannot access the physical machine, mark it as a pending manual acceptance test and provide exact instructions.

---

## 9. BlueSCSI SD card safety

The initial application should produce a standalone `.hda` file for the user to copy manually to the SD card.

Do not write directly to the SD card in the first version.

Do not reformat the SD card, modify other images, alter `bluescsi.ini`, change existing SCSI IDs or delete any existing files.

The application should explain that the completed image normally belongs in the root of the BlueSCSI SD card, alongside any other valid images.

Provide a **Show in Finder** action after successful completion.

The user should be able to copy the image to the card using Finder, without any special installation process.

---

## 10. Suggested project architecture

Keep the code modular but proportionate to a small macOS utility.

Possible structure:

* `App/` — app entry point and lifecycle.
* `UI/` — main window, file queue, settings and progress.
* `Models/` — transfer job, audio file information and image configuration.
* `AudioValidation/` — WAV inspection and compatibility checks.
* `DiskImage/` — image creation, template handling and capacity calculations.
* `HFS/` — HFS file operations and filename sanitisation.
* `BlueSCSI/` — naming conventions and SCSI ID validation.
* `Infrastructure/` — process execution, filesystem operations and logging.
* `Tests/` — unit, integration and fixture-based tests.
* `Documentation/` — format specification, build instructions and physical test procedure.

These are proposed boundaries, not a mandate to create unnecessary abstractions. Use the simplest maintainable architecture that fits the chosen image-manipulation technology.

If external tools are required, investigate how they will be installed, invoked and packaged. Do not assume every user has Homebrew or development utilities installed.

Do not silently download and execute unverified binaries. Document dependency licences, versions and installation or bundling requirements.

When invoking command-line utilities, pass arguments safely without shell-string interpolation, capture their exit status and diagnostics, and run long operations away from the main UI thread.

---

## 11. Testing plan

Create automated tests for:

* BlueSCSI filename generation and validation.
* SCSI ID range and configuration.
* WAV property inspection.
* Invalid, corrupt and unsupported WAV files.
* Filename sanitisation and collisions.
* Capacity calculations.
* Empty queues and duplicate inputs.
* Existing destination-file handling.
* Failed image creation and cleanup.
* Verification of the expected volume layout.
* File integrity after copying into the image.
* Cancellation and failure reporting.

Use test fixtures that include valid WAV files with different lengths and representative properties, plus invalid and corrupt files.

If possible, create an integration test that builds an image from several known WAV files and verifies their presence and checksums independently.

Do not treat a test that merely creates a file with a `.hda` extension as evidence of BlueSCSI compatibility.

Keep the physical Macintosh Plus test as a separate, documented acceptance test.

---

## 12. Documentation and long-term maintenance

Create or update:

* `README.md` — purpose, features and user workflow.
* `SPECIFICATION.md` — functional and compatibility requirements.
* `ARCHITECTURE.md` — image creation strategy and major components.
* `BUILDING.md` — development environment and build instructions.
* `TESTING.md` — automated and physical-machine test procedures.
* `CHANGELOG.md` — meaningful changes by version.

Document the selected image-creation strategy, its dependencies, the source of any template image, the supported audio format, the naming convention and any known limitations.

Keep a clear record of which compatibility requirements have been verified on the real Macintosh Plus and which remain assumptions.

The project must be understandable and maintainable even if development resumes months or years later.

---

## 13. Staged development roadmap

Work in small, verified stages. Do not attempt to implement everything in one large change.

### Stage 0 — Investigation and design

* Inspect the environment and existing MacMusic documentation.
* Research BlueSCSI image requirements.
* Select and justify the device-image creation strategy.
* Establish a minimal test image and compatibility verification method.
* Document the proposed design.

### Stage 1 — Prove the disk-image approach

Before developing the full UI, demonstrate that the chosen tooling can produce or populate a valid Macintosh-compatible `.hda` image containing a test WAV file.

Verify the image structure and document the remaining physical-machine test requirements.

If a suitable template or external utility is required, establish the process and licensing implications first.

Do not proceed as if the approach were proven if the resulting image has only been checked for its filename or file size.

### Stage 2 — Build the core packaging engine

Implement WAV validation, filename handling, capacity calculation, image creation or preparation, copying and verification.

Add automated tests and confirm that multiple files can be packaged without modifying their source files.

### Stage 3 — Implement the native interface

Add file selection, drag and drop, the queue, output settings, progress reporting, cancellation and clear error handling.

Connect the UI to the tested packaging engine.

### Stage 4 — Compatibility and reliability

Test malformed inputs, filename collisions, insufficient capacity, existing outputs and failures during image creation.

Perform the physical Macintosh Plus acceptance test when the hardware is available.

### Stage 5 — Packaging and release preparation

Ensure the application builds on Apple Silicon, document its dependencies, prepare a reliable release build and complete the user documentation.

Commit each meaningful milestone after its tests have passed. Do not make a commit that claims an unverified feature is complete.

---

## 14. Definition of done

The first release is complete when:

* The native macOS app accepts multiple WAV files.
* The app validates the selected audio and reports unsupported files clearly.
* It creates a genuine Macintosh-compatible BlueSCSI device image.
* The image uses a valid BlueSCSI filename and configurable SCSI ID.
* The image contains a `Transfer` HFS volume with a `WAV Files` directory.
* All selected files are copied without changing their audio contents.
* Filename conflicts and capacity limitations are handled safely.
* The output is independently verified to the extent supported by the tooling.
* Failures do not destroy source files or existing completed images.
* The application builds and its automated tests pass.
* The physical Macintosh Plus compatibility test is documented and completed before compatibility is claimed as fully verified.
* The project has sufficient documentation for future maintenance.

## Instructions to Claude Code

Start with Stage 0. Inspect the actual project and available tools before choosing an implementation. Give me a concise investigation report and your recommended technical approach, including any decisions that need my approval.

Do not assume a `.hda` extension makes an image valid. Do not invent compatibility claims. Do not rewrite unrelated projects or features. Prioritise a working, verifiable transfer process over a large feature set.

Once the approach is established, proceed through the roadmap in small stages, testing and documenting each milestone.

---

# 15. Investigation, decisions and findings (kept up to date)

## 15.1 Stage 0 investigation (2026-10-09)

**The environment:** a MacBook Neo (Mac17,5, Apple A18 Pro), macOS
26.4.1, Xcode 26.6 (macOS SDK 26.5), Swift 6.3.3; `xcrun`'s default SDK
lookup fails here, so the scripts name it (as in the converter).

**The target (owner, 2026-10-09):** a Macintosh Plus with **System
6.0.7** (the brief says 6.0.8; the owner confirmed 6.0.7, and MacMusic's
records agree; HFS and the SCSI driver are the same on both), through a
BlueSCSI, **booting from ID 0**.

**A method already proven on that Plus:** MacMusic's release tools
(`MacMusicPlayer/tools/library-image`, `make-release.sh --scratch`) made
`HD50_512 Scratch 1980 MB.hda`, used on the real Plus through BlueSCSI:
1. the first 96 blocks of a known-good BlueSCSI image, the "template":
   kept by MacMusic's environment archive as `bluescsi-template.hda`
   (48 KB). Decoded:

   | Blocks | What |
   |---|---|
   | 0 | driver descriptor ("ER"): 512-byte blocks, the disk's size, one driver at block 64 (19 blocks, type 1) |
   | 1-63 | the Apple partition map: `Apple_partition_map` (1+63), `Apple_Driver43` "Macintosh" (64+32), `Apple_HFS` "MacOS" (96 to the end) |
   | 64-95 | Apple SCSI Driver 4.3 |

2. the disk's size written into the descriptor (`sbBlkCount`) and the
   HFS partition's entry (`pmPartBlkCnt`, `pmDataCnt`) made to reach the
   end;
3. an HFS volume of that size, made with **hfsutils** (`hformat`,
   `hmkdir`, `hcopy`, `hattrib`), appended after block 95.

The 1.0 release image's first 96 blocks are byte for byte the template.

**BlueSCSI's documentation** (bluescsi.com/docs, "Usage" and "Disk
Images", read 2026-10-09):
- only **device images** work: a partition map, a SCSI driver and HFS
  partitions; volume images (HFS alone, Mini vMac's kind) don't;
- **Apple Driver 4.3** is recommended and works on the Plus; LIDO and
  Drive Setup drivers don't work on the Plus; don't mix drivers on one
  machine;
- names: `HDxy_512.hda`, x the SCSI ID (0-7, default 1), y an optional
  LUN (0 only); text after the block size is ignored; at most 64
  characters; e.g. `HD50_512 System 6.0.8L LC.hda`. One image per ID.

**The audio** (verified against MacMusic's importer, `src/wav.c`, in the
MacMusic Converter Utility's SPECIFICATION.md §18.2): RIFF/WAVE, format
1 (plain PCM), 1 channel, 22,050 Hz, 8 bits (unsigned), block align 1,
byte rate 22,050, a non-empty data chunk; no `iPod` chunk (MacMusic adds
it on import). An optional LIST/INFO title (INAM) is read on import.
From 2.0 the rate is 22,254 Hz, byte rate 22,254, the Converter 1.1's
(§15.11).

**The tools here:** hfsutils 3.2.6, built by Retro68
(`~/Retro68-build/toolchain/bin`: arm64, needing only libSystem; source
`~/Retro68/hfsutils`, GPL v2). It keeps a working state file, `~/.hcwd`,
in the home folder. macOS can't mount HFS volumes, so it can't check
them. machfs (PyPI, 1.3, MIT), a separate HFS reader and writer, is
available for tests.

## 15.2 Stage 0 decisions (2026-10-09, approved by the owner)

- **Q1, identity:** the app is the **MacMusic Transfer Utility** (window
  title "MacMusic Transfer"); its own repository,
  `~/MacPlusProjects/MacMusicTransfer/`; bundle identifier
  **`local.macmusic.transferutility`** (the converter keeps
  `local.macmusic.transfer`: two apps can't share one).
- **Q2, the image method:** the proven template method above; the
  template's structures used as they are, only their size fields set; no
  structure invented, no driver installed.
- **Q3, the template:** contains Apple's driver, so kept out of the
  repository; the build copies MacMusic's archived `bluescsi-template.hda`
  into the app (own use). Another may be chosen; any template is checked
  (an Apple partition map, `Apple_Driver43`, `Apple_HFS` at block 96) and
  refused otherwise.
- **Q4, the HFS tool:** hfsutils (Retro68's), inside the app in Stage 5;
  each job with a private HOME, so `.hcwd` can't be shared. GPL v2,
  recorded in the notices.
- **Q5, verification:** (1) the app's own HFS reader, in Swift,
  independent of hfsutils: the partition map, the volume's name, the
  `WAV Files` folder, every file's presence, size and SHA-256 against its
  source; (2) machfs in the tests, a third reader; (3) the owner's test
  on the Plus, which nothing replaces.
- **Q6, sizing:** the files plus 25%, plus 4 MB for HFS's own
  structures, rounded up to a MB, at least 10 MB; the formatted volume's
  real free space checked before copying; at most 2 GB (System 6). One
  policy function.
- **Q7, the WAV rules:** a copy of the converter's validator (MacMusic's
  `wav.c`, rule by rule); MacMusic is the source of truth. Files that
  fail are refused, pointing to the Converter; nothing re-encoded;
  sources never changed.
- **Q8, names on the Mac:** at most 31 characters with `.wav`; no
  colons; Mac Roman (others transliterated); case-insensitive clashes made
  unique ("Song 2.wav"); the window shows each "from → to" before
  building. Data forks only, type `WAVE`; no resource forks or hidden
  files.
- **Q9, the SCSI ID:** 0-6 (7 is the Mac); **default 6** (the owner's
  choice); a strong warning for 0, the owner's boot disk; a reminder that
  one image per ID is used.
- **Q10, the output:** `HD<id>0_512 Transfer.hda` (an explicit LUN 0, as
  the proven `HD50_512`), so **`HD60_512 Transfer.hda`** by default; built
  as a temporary file, moved into place only once verified; an existing
  file replaced only when the user agrees. The SD card is never written.

## 15.3 Stage 1 findings (2026-10-09)

- **hfsutils formats the HFS partition in place,** inside the image
  (`hformat -l Transfer <image> 1`, `hmount <image> 1`): no separate
  volume to build and join on (MacMusic's method), so no second copy of
  the disk. The first 96 blocks are left exactly as the template's,
  sized: checked byte for byte in every test.
- **hfsutils stores names as the bytes it's given,** and Foundation's
  Process passes arguments as UTF-8 (decomposed): "Café" was stored as
  "CafeÃÅ". The engine now starts hfsutils with posix_spawn and each HFS
  path as exact Mac Roman bytes (`RawSpawn`); names not in Mac Roman are
  refused. Found by the tests.
- **`hcopy` accepts "--", `hattrib` doesn't;** hattrib's argument is
  always an HFS path beginning ":", so it can't be read as an option.
- **machfs (1.3) doesn't keep the volume's name** in `read()` (it shows
  "Untitled"); its test reads the name from the Master Directory Block
  itself. machfs agrees on every file's name, type and SHA-256.
- **The proof image:** `HD60_512 Transfer.hda`, 13 MB (Q6's sizing for
  7.3 MB of WAVs), two songs made by the Converter, verified by the Swift
  reader, machfs and checksums; the sources unchanged.
- **The real Plus (2026-10-09):** the owner copied the proof image to
  the BlueSCSI's card and booted the Plus from ID 0: "disk is there and
  the WAV files are too. no issues." **Stage 1's acceptance criterion is
  met: the method works on the target machine.** (Importing from it into
  MacMusic wasn't reported separately; TESTING.md.)

## 15.4 Stage 2 decisions (2026-10-09, approved by the owner)

- **V1, checking the WAVs:** the converter's copy of MacMusic's `wav.c`
  rules (`MacMusicWAVValidator`, `WAVFile`, `MacMusicFormat`, each marked
  with its source of truth); every file's format, rate, channels, bits,
  length (from its own byte rate) and size read from the file; anything
  else refused with its reason and a pointer to the Converter.
- **V2, names on the Mac:** the converter's rules (`MacNames`); clashes
  judged as HFS does, ignoring case, made unique ("Song 2.wav") in list
  order; each change shown "from → to".
- **V3, duplicates:** the same file (after resolving links) ignored, with
  a note; identical files at different paths both kept, with a note.
- **V4, the job:** stages Checking, Preparing, Formatting, Copying ("3 of
  12", a real fraction), Verifying, Finishing; built as a hidden
  `.mtu-….hda.partial` beside the destination; moved into place only
  once verified; cancellable at every stage, leaving nothing; sources
  and finished images never touched.
- **V5, an image already there:** refuse (the default; the app asks),
  replace, or keep both ("HD60_512 Transfer 2.hda", with a warning that
  both use the same ID).
- **V6, the size:** the estimate and its working shown; the formatted
  volume's real free space checked before copying; over 2 GB refused.
- **V7, the summary:** every file "from → to", size and SHA-256, and
  every check; shown and copyable, never written beside the image.
- **V8, tests:** as listed in TESTING.md.

## 15.5 Stage 2 findings (2026-10-09)

- **A refused file was given a Mac name** ("Song 2.wav" for an MP3),
  taking a name a real file might need, and the estimate counted it:
  refused files now take no name and aren't counted. Found by trying
  `mtu-build` on a mixed set.
- **Sources are re-checked** before the build (their size) and after it
  (their SHA-256), so a file changed after it was added is refused, not
  packaged.
- **Stage 2's acceptance criterion is met:** many files packaged through
  the engine without the window, verified three ways, sources unchanged.
  The engine uses Stage 1's method unchanged, so the Plus test then
  stands; the app's own images get their own Plus test in Stage 4.

## 15.6 Stage 3 decisions (2026-10-09, approved by the owner)

- **U1, the window:** Files (drop or Add Files…; a table: File, On the
  Mac, Format, Length, Size, Status; Remove, Clear All, totals, notes);
  Disk (SCSI ID, the file name, its warnings, the volume, the size and
  how it's worked out); Save To; Advanced; Build Transfer Image, the
  stage and a bar that fills while copying, Cancel; the Result (Show in
  Finder, Copy Summary, the card reminder, what was checked).
- **U2:** saved by default to `~/Music/MacMusic Transfer`; remembered.
- **U3:** an image already there: Keep Both (the default), Replace,
  Cancel, with the same-ID reminder.
- **U4:** ID 0 shown as the boot disk's, warned of in orange, and
  confirmed before building.
- **U5 (the owner's choice):** a folder adds the .wav files directly in
  it, not those in folders within; anything left out is noted.
- **U6:** quitting or closing mid-build asks, then stops hfsutils (the
  converter's AppDelegate and close guard).
- **U7:** remembered: the folder, the ID, the template, the window's
  place; not the list.
- **U8:** Advanced shows the template and its check, with Choose… and
  Use Default.
- **U9:** the window's logic tested in the engine; the window tried by
  the owner (TESTING.md): "Happy".
- **The icon (the owner's request):** the Converter Utility's, with a
  double arrow (⇄) in its red badge (`Resources/Icon/AppIcon.svg`;
  `tools/make-icon.sh`, from the converter's).

### 15.7 Stage 4: compatibility and reliability (L1–L4)

- **L1, scale** (`ScaleTests`): 500 short files, and a disk of about
  100 MB (four 15-minute files) whose allocation blocks are larger than
  512 bytes. Both built and verified; the HFS reader needed no change
  (no extents-overflow records arise at these sizes).
- **L2, failures mid-build** (`FailureTests`): a 4 MB disk image made with
  `hdiutil` (refused up front for want of space; and, with the check
  skipped, filling mid-write); a stand-in `hcopy` failing on the third
  file; a source made unreadable after it was added; the save folder
  removed mid-build. Each ends with a plain error, no `.hda` and no
  hidden part-made image left behind, and the sources untouched.
- **L3, leftovers after a crash** (`Leftovers`): at launch the app removes
  its own temporary files, recognised by name (`.mtu-*.partial` in the
  save folder; `mtu-job-*`, `mtu-spawn-*`, `mtu-build-*` in the
  temporary folder), only when over an hour old. Others' files are never
  touched.
- **L4, a Plus test set**: 13 twenty-second tones, made with the engine,
  with "Café", a name over 31 characters, a name with a colon, and two
  names differing only by case (from two folders). Built and verified on this Mac; the check on the Plus
  is still to be done (no compatibility is claimed until it is).

### 15.8 Stage 5: packaging and v1.0 (R1–R8)

- **R1:** `tools/build-app.sh` copies the 8 hfsutils tools used from
  Retro68's build into `Contents/Helpers/hfsutils`, each signed ad hoc,
  with hfsutils' COPYING and COPYRIGHT (GPL) in
  `Contents/Resources/hfsutils` (the signature allows no plain files
  among the helpers). These tools are arm64 only, so the app runs on
  Apple-silicon Macs only.
- **R2:** the template's 96 blocks go into
  `Contents/Resources/bluescsi-template.hda`, copied from
  `~/MacPlusProjects/environment-1.0/` at build time; never in the
  repository. Releases are for the owner's own use (Apple's driver).
  A template chosen in Advanced still comes first.
- **R3 (`Bundled`):** the packaged app uses its own hfsutils and template
  only; the development copies (Retro68's build, the archived template,
  `MTU_HFSUTILS`) are used only when run from the repository.
- **R4 (`SelfTest`):** `MacMusicTransfer --self-test` opens no window,
  makes three one-second WAVs (one "Café.wav") in a temporary folder,
  builds an image with the app's own tools and template, has the
  independent reader check it, removes everything, prints the report and
  exits 0 if it passed. Passed six times in a row on this Mac, leaving
  nothing behind.
- The tests' own folders are now removed after each test (2.4 GB of them
  had built up in the temporary folder).
- **R5 (`tools/make-release.sh`):** as the Converter's. From committed
  source only (and a clean Retro68 hfsutils), it runs the tests, builds
  the app, runs the self-test on a copy outside the repository, and
  writes `~/MacPlusProjects/releases/MacMusic-Transfer-Utility-<version>/`:
  the zip, the release notes, SHA256SUMS, a git bundle of the source,
  hfsutils' exact source (`git archive` of Retro68's `hfsutils` at the
  commit it was built from), and the checks. Tried on a throwaway clone
  first: all passed, 2.1 MB in all.
- **R6 (`Documentation/RELEASE-NOTES.md`):** installing, using it step by
  step, what was checked (only what was seen on the Plus: a PLUS-CHECK
  line marks what is still to be recorded before 1.0 is tagged), safety,
  the bundled software and the limits.
- **R7:** the version is "1.0" (as the Converter's); the tag `v1.0` only
  after the Plus checks.

**To finalise 1.0 (open, 2026-10-09): a check on the real Plus.** The
release candidate (`~/MacPlusProjects/releases/MacMusic-Transfer-Utility-1.0/`,
from 77db85a) is made, but 1.0 isn't final until the owner has checked,
on the Macintosh Plus under System 6.0.7:
1. the Stage 4 test image (`~/MacPlusProjects/transfer-work/plus-test-set/out/`):
   the names (Café, the shortened long name, `Rock- Live.wav`,
   `clash 2.wav`), and two songs imported into MacMusic and played;
2. an image built by the release candidate's app (unzipped outside the
   repository): mounted, one song imported and played.
Then: the release notes' PLUS-CHECK line replaced by the result, the
release remade, the tag `v1.0`, `make-release.sh --bundle`, and 5c (R8,
MacMusic's environment archive).

**Changes after the first candidate (2026-10-10), from the owner's
screenshots:** sizes shown the Finder's way (decimal megabytes), the
file list's columns tightened, and free space read correctly on
non-APFS disks. The 1.0 candidate remade; the Plus check still to do.

**The Plus check (2026-10-26): passed.** Both images above, on the owner's
Plus: "names fine, songs imported and played" (TESTING.md). 1.0 is
final: the release notes' PLUS-CHECK line replaced, the release remade,
tagged `v1.0`. 5c (R8, MacMusic's environment archive) is left to a
MacMusic session (the owner, 2026-10-26).

## 15.9 Macintosh Transfer Utility 2.0: decisions (2026-10-26, approved by the owner)

The owner decided (2026-10-26, with the MacPhoto Utility session) that
the app becomes the **Macintosh Transfer Utility**: the same app, also
putting the MacPhoto Utility's pictures on the transfer image. For this
app that reverses Q11/P17 ("MacMusic-specific"); the programme's record
is P25 (`~/MacPlusProjects/Programme/DECISIONS.md`).

- **M1, the baseline:** 1.0 finished first as the MacMusic Transfer
  Utility (§15.8): checked on the Plus, tagged `v1.0` (0759ea0).
- **M2, names:** the app "Macintosh Transfer Utility", its window
  "Macintosh Transfer"; the package and modules `MacintoshTransfer`,
  `MacintoshTransferKit`; the developer's tool stays `mtu-build`; the
  release folder `Macintosh-Transfer-Utility-<version>`. The volume
  ("Transfer") and the image's name (`HDx0_512 Transfer.hda`) don't
  change. The temporary files keep their `mtu-` names, so 1.0's
  leftovers are still cleared.
- **M3, the bundle identifier:** kept, `local.macmusic.transferutility`
  (as the Macintosh Backup Utility keeps `local.macmusic.backuputility`):
  the settings stay in the same domain, and macOS's folder permissions
  carry over.
- **M4, the preferences:** the key becomes
  `MacintoshTransferUtility.preferences`; the first time, 1.0's key is
  copied to it, and left for 1.0.
- **M5, the save folder:** `~/Documents/Macintosh Transfer` by default;
  but 1.0's `~/Music/MacMusic Transfer` if it exists, so nothing moves.
- **M6, the SCSI ID:** stays 6 by default (the owner's choice). The
  owner's card also has `HD60_512 Projects.hda` at ID 6; the window's
  one-image-per-ID reminder stands.
- **M7, the version:** 2.0.
- **M8, the repository folder:** `~/MacPlusProjects/MacintoshTransfer`,
  renamed after T1 is committed, at a step boundary.
- **M9, kinds of file:** each kind has its folder, type, creator, Mac
  name rule, validator, window columns and size. A file is recognised
  by its content; its extension is only a hint. A file of no known kind
  is refused with its reason. The queue may mix kinds; names clash only
  within a folder. The verifier checks each kind's folder, type and
  creator, and that the root holds only the folders used.
- **M10, a regression test:** a WAV-only image matches 1.0's layout:
  the 96 blocks, the volume, only "WAV Files", the names, `WAVE`/`????`,
  the sizes and SHA-256s (structurally: hformat stamps dates).
- **M11, folders on the volume,** each only when its kind is present:
  "WAV Files"; "MacPaint Files"; "PICT Files" (1-bit screen PICTs);
  "Print Files" (8-bit print PICTs). Both PICTs end `.pict`, so only
  their content tells them apart.
- **M12, picture names:** keep the kind's extension (`.MAC`, `.pict`),
  within 31 characters, as `.wav` is now.
- **M13, the validators:** written from the contract and the public
  specifications (MacPaint: Apple Technical Note #86; PICT: Inside
  Macintosh: Imaging With QuickDraw), not from MacPhoto's code. The
  contract is the MacPhoto Utility's `Documentation/FILE_FORMATS.md`
  (draft 0.3, approved by the owner as the working contract,
  2026-10-26; provisional until its format 1.0):
  - MacPaint `.MAC`, `PNTG`/`MPNT`: a 512-byte header of zeros (version
    0); 720 rows of 72 bytes, each row packed alone; padded to a
    multiple of 512 bytes (a shorter file accepted); the 512 × 342
    image centred (rows 189-530, bytes 4-67), the rest white (PH12).
  - Screen PICT `.pict`, `PICT`/`MPho`: version 1, 512 × 342, 1-bit,
    one PackBitsRect (PH17, PH18).
  - Print PICT `.pict`, `PICT`/`MPho`: version 2, 8-bit grey, a fixed
    set of opcodes with MacPhoto's LongComment record and its CRC-32;
    750 × 1050, 1050 × 750, 900 × 1260 or 1260 × 900 (PH16, PH19).

  Fixtures: our own, and MacPhoto's `Fixtures/handoff/` copied into
  `Tests/`. The self-test makes one file of each kind. Notes from
  MacPhoto: macOS's ImageIO draws these PICTs blank, so it is no
  reference reader; other people's PICTs often carry data in the
  512-byte header. **Open for T3:** accept only MacPhoto's PICTs, or
  others' too (then not requiring the zero header)?
- **M14, Plus checks** before anything is called compatible: a 2.0
  WAV-only image (mounts; a song imported and played); a mixed image
  (its folders; MacPaint documents with MacPaint's icon, opening in
  MacPaint; PICTs and their type and creator; the names).
- **After Dark** (on the owner's boot disk) shows PICTs from its own
  Slide Show Folder there. The app writes only its own volume, so it
  doesn't place them; the release notes say to drag the screen PICTs
  from "PICT Files" into Slide Show Folder on the Plus (the owner).

**Stages,** in this order (the owner): T1 the rename (M2-M8); T2 kinds
of file, WAV only (M9-M11); T3 MacPaint and both PICTs (M12-M13); T4
the combined Plus test (M14) and release 2.0. (The plan's separate
print-master stage went with `.mppi`, PH16.)

## 15.10 T2, kinds of file, WAV only: decisions and findings (2026-10-27, approved by the owner)

The plan for M9-M11, with WAV the only kind, so T3 adds MacPaint and
the PICTs to an engine already built for them.

- **K1, `FileKind`:** each kind's name, folder, type and creator, Mac
  extension, the extensions that hint at it, its content check, its
  validator's details (`FileDetails`), its words, and its type for the
  Open panel. T2: `.wav` ("WAV Files", `WAVE`/`????`, `.wav`). T3 adds
  `.macPaint`, `.screenPICT`, `.printPICT` in that order, which is the
  folders' order on the volume (M11). `Layout` keeps the volume's name.
- **K2, recognised by content (M9):** a file's kind is what its first
  bytes say (a WAV: `RIFF….WAVE`), whatever it's called; its Mac name
  is its name without its extension, plus the kind's (so 1.0's `.wav`
  names are unchanged; `Song.dat` goes on as `Song.wav`). A file of no
  known kind is refused: "It isn't a kind of file that can go on the
  disk (MacMusic WAVs)."; named as a kind but not one: "It isn't a WAV
  file, though its name ends in .wav." A WAV not in MacMusic's format is
  refused as in 1.0.
- **K3, a folder:** adds the files directly inside it that are a known
  kind by content, or named as one (a damaged `.wav` is still shown with
  its reason); the rest is counted in the note; not from folders within
  (U5).
- **K4, the queue:** each file carries its kind (nil if none) and its
  details; names clash only within a folder.
- **K5, the builder:** a folder only for each kind present, in K1's
  order; each file with its kind's type and creator.
- **K6, the verifier:** the root holds exactly the folders used; each
  holds exactly its files; each file's size, SHA-256, no resource fork,
  its kind's type and (new) creator.
- **K7, the result:** each file's folder; the summary names the folders
  (with only WAVs, as 1.0's: folder "WAV Files").
- **K8, the window:** the Format column from each kind's details;
  Length blank for a kind that doesn't play, and the total length only
  when something plays; the "Volume" line names the folders to be made;
  the Open panel's types from the kinds. The words stay WAV-only until
  T3 (the drop text, "Add some WAV files first", the Converter advice).
- **K9, sizing:** unchanged (Q6), every kind by its bytes.
- **K10, the regression test (M10):** against a record made by 1.0's
  own code (see the findings).
- **K11, `mtu-build`:** prints each file's folder; its usage says
  `<file> …`. The self-test is unchanged (T3 adds one of each kind).
- **K12:** the tests and documents.

**Findings (2026-10-27):**

- **1.0's image, recorded:** `v1.0` was exported (`git archive`) to the
  scratchpad, its `mtu-build` built, and five WAVs (made as the tests'
  `Fixtures.wav` makes them) built into an image with it. Two such
  builds, a few seconds apart, differ in 22 bytes, all dates: the
  volume's created and modified dates in the Master Directory Block and
  its copy at the volume's end; the catalog records' dates; and dates in
  the free space of catalog nodes, where hfsutils leaves old copies of
  records it moved when splitting a node. With those masked (zeroed),
  the two builds are identical, and 2.0's build of the same files is
  identical to them: `RegressionTests` holds the record (its size, its
  first 96 blocks' SHA-256, every catalog entry, the masked image's
  SHA-256). Only the record is in the repository; nothing of 1.0's
  build or image.
- The Open panel offers only files of the kinds' types (`.wav`); a WAV
  under another name can be dropped on the window, or added from a
  folder, but not chosen in the panel.
- Names clashing only within a folder can't be tested until there's a
  second folder (T3); with one folder it is 1.0's rule, and the existing
  clash tests pass unchanged.
- **Assumed, not verified:** a 2.0 WAV-only image is the same as 1.0's
  apart from its dates, by the test above. It hasn't been tried on the
  Plus yet (M14, in T4).

## 15.11 The Plus's own rate, 22,254 Hz: decisions and findings (2026-11-12, approved by the owner)

The Converter 1.1 makes MacMusic WAVs at 22,254 Hz, the Plus's own
rate (the hardware's 22,254.5, to the whole number a WAV holds): at
22,050 Hz songs played 0.93% fast on the Plus (MacMusic's issue I4;
the Converter's commit 5a3acc7, its SPECIFICATION §18.25). MacMusic 1.2
(committed, not yet released) imports 22,050 or 22,254 Hz, its byte
rate equal to its rate, and nothing else, not even 22,255 (`src/wav.c`,
N12-4). The request came from the Converter session.

- **W1, one rate (the owner's choice):** `MacMusicFormat`'s rate and
  byte rate are 22,254, as the Converter's copy's are; not both rates,
  though MacMusic 1.2 takes both. A 22,050 Hz song made before the
  Converter 1.1 is refused, and needs converting again.
- **W2, the check:** unchanged but for naming the rate from
  `MacMusicFormat`: "Its sample rate is 22050 Hz, not 22254."; a byte
  rate other than 22,254 is "inconsistent".
- **W3, the length:** unchanged; it was already from the file's own
  byte rate.
- **W4, the window:** unchanged; the Format column ("22.254 kHz mono
  8-bit") and the description ("22,254 Hz") are the file's own.
- **W5, the regression test (M10):** 1.0 took only 22,050 Hz, 2.0 only
  22,254, so no files pass both checks. The test's five WAVs stay at
  22,050 Hz and go straight to the image builder (as the engine gives
  them, with the names 1.0 gave them), and the image is verified; the
  record is unchanged. It still shows the image's layout is 1.0's; the
  queue's naming is tested in `QueueTests`.
- **W6, the tests and self-test:** the fixtures and the self-test's tone
  at 22,254 Hz; a new test: 22,254 accepted with its length; 22,050 and
  22,255 refused, each with its rate; a byte rate of 22,050 refused as
  inconsistent.

**Findings (2026-11-12):** 49 tests and the record (skipped), all
passing. `mtu-build` goes through the same queue, so it takes the same
rate. **Assumed, not verified:** that MacMusic 1.2 on the Plus imports
22,254 Hz songs from a Transfer disk; it needs the owner's test there.
