# Testing

## Automated (`tools/test.sh`)

Swift Testing; no network, no audio tools: the WAVs are made byte by
byte at 22,254 Hz (22,050 for 1.0's). The images are real, made by
hfsutils (Retro68's) from the archived template. machfs
(`~/MacPlusProjects/transfer-tools/venv`, BUILDING.md) is used when it's
there.

| Suite | Checks |
|---|---|
| `BlueSCSITests` (3) | `HD60_512 Transfer.hda` and the name for each ID, within 64 characters; names read as BlueSCSI's documentation reads its examples; IDs 0-6, 7 refused; the boot-disk warning for 0 |
| `TemplateTests` (4) | the archived template's map (`Apple_partition_map`, `Apple_Driver43`, `Apple_HFS` at 96); sizing changes only the three size fields, the driver untouched; junk, short and driverless templates refused; the sizing policy |
| `ImageTests` (8) | an image of three WAVs verified (the map and driver exactly the template's after formatting; block 96 to the end; "Transfer"; only "WAV Files"; exactly the files; sizes, SHA-256, type WAVE, no resource fork); the Swift reader's view (an accented name stored as Mac Roman); **machfs agreeing** on every name, type and SHA-256; the verifier catching a changed byte and a missing file, a wrong creator and an extra folder; too small refused before copying; hfsutils' state in the job's own HOME; the sources unchanged |

| `QueueTests` (9) | the rate: 22,254 Hz accepted with its length, 22,050 and 22,255 refused with their rates, a byte rate of 22,050 refused as inconsistent; kinds by content (a WAV named `.dat` or with no extension taken as `….wav`; a text file refused with the kinds listed), each file's folder, the queue's folders; the kinds' folder, type, creator, extension, hints, recognition; a MacMusic WAV ready; stereo, 16-bit 44.1 kHz, 44.1 kHz, extensible, truncated, empty and non-WAV files refused, each with its real properties and reason; the naming rules; case-insensitive clashes made unique; refused files taking no name or size; duplicates ignored, identical files noted, folders and missing files noted, remove and clear |
| `WindowLogicTests` (5) | a folder adding the WAVs directly in it, in name order, noting what's left out, and its subfolders' not at all; an empty folder noted; from a folder, files of a known kind by content or name (a WAV named `.dat`; a damaged `.wav` shown with its reason), nothing else; the preferences saved and loaded, a bad ID reset; 1.0's preferences carried over once and left for 1.0; the default folder, 1.0's if it's there |
| `EngineTests` (9 + 3) | twelve files built and verified three ways, the stages in order, copying counted file by file, sources unchanged, nothing else left in the folder; other IDs, 7 refused; an empty queue, a refused file, a missing folder; an existing image refused, kept beside (`… Transfer 2.hda`), replaced, the original untouched; cancelling at each of four stages leaving nothing; a source changed after adding; a bad template; the size explained; renamed files arriving renamed |
| `RegressionTests` (2 + 1) | **a WAV-only image is 1.0's (M10):** five 22,050 Hz WAVs (an identical pair, "Café", two long names cut to one), given straight to 2.0's image builder with 1.0's names and verified, match the record of the image 1.0's `mtu-build` made from them: its size, its first 96 blocks, every catalog entry (IDs, names, type, creator, lengths, where the data is, SHA-256), and the whole image's SHA-256 with HFS's dates masked; two builds differing only in those dates; `recordTheImage`, run only with `MTU_V1_IMAGE` set, prints an image's record |

Stage 3: 31 tests (including the four cancelling stages), all passing
(2026-10-09), in about 2 s. T2: 48 tests and the record (skipped), all
passing (2026-10-27), in about 15 s (most of it `ScaleTests`). The
22,254 Hz rate (§15.11): 49 tests and the record, all passing
(2026-11-12).

## Trying the window (Stage 3)

The window's logic is tested above (`WindowLogicTests`); the window is
checked by trying it:

    tools/build-app.sh && open "build/Macintosh Transfer Utility.app"

1. **Adding:** drop two or three Converter WAVs on the window (or Add
   Files…): each row shows its format, length, size and a ✓. Drop a
   folder: its WAVs come in (not those in folders within), with a note
   of anything left out. Drop the same file again: "already in the
   list".
2. **A wrong file:** add an MP3, or a CD-quality WAV: "Can't be used"
   (hover for why), a red line under the list, and Build dimmed. Remove
   it (select, Remove or Delete): Build is back.
3. **Names:** a WAV with a long name, or "a:b.wav": "On the Mac" shows
   the new name in orange.
4. **The disk:** the SCSI ID is 6, the file name `HD60_512 Transfer.hda`;
   change it to 2: `HD20_512 Transfer.hda`; choose 0: the orange boot-disk
   warning. The size, with "How is this worked out?".
5. **Build:** the stages, the bar filling while copying; the result:
   the name, size, free space, "verified"; Show in Finder; Copy Summary
   (paste it somewhere: every file and check); "What was checked".
6. **Again:** Build again: "already in …": Keep Both (`… Transfer 2.hda`
   and the same-ID warning), then Replace, then Cancel.
7. **ID 0:** with ID 0, Build asks first.
8. **Cancel:** with a dozen files, Cancel (or Esc) during Copying:
   "Cancelled. Nothing was saved."; no hidden `.mtu-…partial` left in the
   folder (Finder: Cmd-Shift-. shows hidden files).
9. **Quitting mid-build:** ⌘Q, then the window's close button, during a
   build: "Stop building the disk and quit?".
10. **Remembered:** quit and reopen: the ID and the folder as left; the
    list empty.
11. **Advanced:** the template "OK: Apple_partition_map, Apple_Driver43,
    Apple_HFS"; Choose… a non-disk file: "Can't be used", Build dimmed;
    Use Default.

## On the real Macintosh Plus: the acceptance test (brief §8)

Nothing else can show the Plus accepts an image. Record each run here.

**Before:** the Plus off. Take the SD card out of the BlueSCSI and put it
in this Mac. **Check it has no other image using ID 6** (a name starting
`HD6`): BlueSCSI uses one image per ID, and your boot disk is ID 0
(`HD0…`). Don't change or remove anything else on the card.

1. Copy `HD60_512 Transfer.hda` to the **root** of the card (not into a
   folder), with the Finder. Eject the card properly.
2. Put the card back in the BlueSCSI; switch on the Plus; let it boot
   from your usual disk (ID 0).
3. **The disk appears** on the desktop, named **Transfer**.
4. **Open it:** it holds one folder, **WAV Files**.
5. **Open the folder:** every file you put in is there, with its name as
   shown when it was built.
6. **In MacMusic:** File > Import Song, choose the Transfer disk, the WAV
   Files folder, a song; it imports (the title filled in if the WAV has
   one) and plays properly.
7. **Intact:** each imported song plays to its end without noise or
   cut-outs.

Afterwards you may leave the image on the card, or delete it with the
Finder on this Mac. Nothing else on the card is affected either way.

### Runs

- **Stage 1's proof image** (`~/MacPlusProjects/transfer-work/HD60_512
  Transfer.hda`, 13 MB, "Good Luck, Babe!.wav" and "Chill Dreamy Lounge
  by.wav", made 2026-10-09): **passed, 2026-10-09**, on the owner's
  Macintosh Plus (System 6.0.7, BlueSCSI, booting from ID 0): "disk is
  there and the WAV files are too. no issues." The disk appeared as
  Transfer, with WAV Files and both songs (steps 1-5). Importing and
  playing them in MacMusic (steps 6-7) wasn't reported separately; the
  same WAVs were imported and played in MacMusic earlier (the Converter's
  Stage 1, Mini vMac).
- **1.0's check (2026-10-26)**, on the same Plus: (1) Stage 4's test set
  (`~/MacPlusProjects/transfer-work/plus-test-set/out/HD60_512
  Transfer.hda`): the names fine (Café, the shortened long name,
  `Rock- Live.wav`, `clash 2.wav`); songs imported into MacMusic and
  played. (2) An image made by the release candidate's app (from
  8955326), unzipped outside the repository: mounted; a song imported
  and played. The owner: "names fine, songs imported and played";
  both images checked. **Passed** (steps 1-7).
