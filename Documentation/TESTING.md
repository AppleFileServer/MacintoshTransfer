# Testing

## Automated (`tools/test.sh`)

Swift Testing; no network, no audio tools: the WAVs are made byte by
byte. The images are real, made by hfsutils (Retro68's) from the archived
template. machfs (`~/MacPlusProjects/transfer-tools/venv`, BUILDING.md)
is used when it's there.

| Suite | Checks |
|---|---|
| `BlueSCSITests` (3) | `HD60_512 Transfer.hda` and the name for each ID, within 64 characters; names read as BlueSCSI's documentation reads its examples; IDs 0-6, 7 refused; the boot-disk warning for 0 |
| `TemplateTests` (4) | the archived template's map (`Apple_partition_map`, `Apple_Driver43`, `Apple_HFS` at 96); sizing changes only the three size fields, the driver untouched; junk, short and driverless templates refused; the sizing policy |
| `ImageTests` (7) | an image of three WAVs verified (the map and driver exactly the template's after formatting; block 96 to the end; "Transfer"; only "WAV Files"; exactly the files; sizes, SHA-256, type WAVE, no resource fork); the Swift reader's view (an accented name stored as Mac Roman); **machfs agreeing** on every name, type and SHA-256; the verifier catching a changed byte and a missing file; too small refused before copying; hfsutils' state in the job's own HOME; the sources unchanged |

Stage 1: 14 tests, all passing (2026-10-09).

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
