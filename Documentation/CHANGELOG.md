# Changelog

## 1.0 (candidate)

- Stage 5: hfsutils and the disk template inside the app, which uses
  only its own copies; `--self-test`; `tools/make-release.sh` and the
  release notes. The tests remove their own folders. 40 tests.
- Stage 4: 500 files and a 100 MB disk built and verified; failures
  mid-build (a full disk, hfsutils failing, an unreadable file, the save
  folder removed) leave nothing behind; leftovers from a crash cleared at
  launch; a test set for the Plus.

## 0.1.0 (in development)

- Stage 3, the window: files dropped or added (a folder's WAVs, one
  level), the table with each file's Mac name, format and status, the
  SCSI ID and file name, the size and its working, the save folder, the
  template (Advanced), the build with its stages and Cancel, the result
  with Show in Finder and Copy Summary; the boot-ID and existing-image
  questions; asking before quitting mid-build; choices remembered. The
  icon: the Converter's, with a double arrow. 31 tests.
- Stage 2, the packaging engine: the queue (each WAV read and checked
  with MacMusic's rules, its Mac name, clashes ignoring case,
  duplicates), the job (stages, a hidden temporary image, verified
  before it's moved into place, cancelling, an existing image refused,
  replaced or kept beside), the summary; `mtu-build` on the engine; 29
  tests.
- Stage 1 (the proof; it mounted on the real Plus, 2026-10-09): images made from the
  template with hfsutils formatting the HFS partition in place; names as
  Mac Roman bytes; an independent HFS reader; verification against the
  template, by the reader and machfs, with SHA-256s; `mtu-build`; 14
  tests.
- Stage 0: the investigation (SPECIFICATION.md §15.1) and decisions
  Q1-Q10 (§15.2).
