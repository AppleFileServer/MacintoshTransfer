# Macintosh Transfer Utility

A macOS app for a Macintosh Plus: it puts files onto a BlueSCSI hard
disk image, `HD60_512 Transfer.hda`, holding an HFS volume "Transfer",
ready to copy to the BlueSCSI's SD card. Today: MacMusic WAV files (made
by the MacMusic Converter Utility), in a "WAV Files" folder. Coming in
2.0: the MacPhoto Utility's pictures (MacPaint documents and PICTs).

**Status:** 1.0 released as the **MacMusic Transfer Utility** (tag
`v1.0`, checked on the real Plus, 2026-10-26). **2.0 in development**
as the Macintosh Transfer Utility (`Documentation/SPECIFICATION.md`
§15.9): stage T1, the rename, done; WAVs only so far.

    tools/build-app.sh && open "build/Macintosh Transfer Utility.app"

| Document | |
|---|---|
| `Documentation/SPECIFICATION.md` | the brief; the investigation, decisions and findings (§15) |
| `Documentation/ARCHITECTURE.md` | how it's built, and the image's layout |
| `Documentation/BUILDING.md` | the environment and the build |
| `Documentation/TESTING.md` | the tests, and the test on the real Plus |
| `Documentation/CHANGELOG.md` | changes by version |

Copyright © 2026 Jack McAteer. Not affiliated with Apple.
