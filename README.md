# MacMusic Transfer Utility

A macOS app for the MacMusic project: it puts MacMusic WAV files (made by
the MacMusic Converter Utility) onto a BlueSCSI hard disk image,
`HD60_512 Transfer.hda`, holding an HFS volume "Transfer" with a "WAV
Files" folder, ready to copy to the BlueSCSI's SD card for a Macintosh
Plus.

**Status: Stage 0** (`Documentation/SPECIFICATION.md` §13, §15): the
investigation and design. Stage 1 proves the image method.

| Document | |
|---|---|
| `Documentation/SPECIFICATION.md` | the brief; the investigation, decisions and findings (§15) |
| `Documentation/ARCHITECTURE.md` | how it's built, and the image's layout |
| `Documentation/BUILDING.md` | the environment and the build |
| `Documentation/TESTING.md` | the tests, and the test on the real Plus |
| `Documentation/CHANGELOG.md` | changes by version |

Copyright © 2026 Jack McAteer. Not affiliated with Apple.
