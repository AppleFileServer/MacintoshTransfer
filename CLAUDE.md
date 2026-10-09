# MacMusic Transfer Utility

## Project

A native macOS app that packages MacMusic's WAV files into a BlueSCSI
hard disk image (`HD60_512 Transfer.hda`) for a real Macintosh Plus
(System 6.0.7, through BlueSCSI, booting from ID 0). The requirements:
`Documentation/SPECIFICATION.md` (the owner's brief, unedited;
investigation, decisions and findings in §15).

Related projects (don't change them unless asked):
- `~/MacPlusProjects/MacMusicPlayer/`: MacMusic, the 68K player. Its
  importer (`src/wav.c`) defines the WAV format; its release tools made
  the BlueSCSI image method this app uses.
- `~/MacPlusProjects/MacMusicConverter/`: the MacMusic Converter Utility,
  which makes the WAVs.

## Build and test

    tools/test.sh          # the engine's tests (swift test)

## Working rules

- **Plan before coding** with numbered decisions; wait for approval;
  record them in SPECIFICATION.md §15.
- **Stage by stage** (brief §13); meet each acceptance criterion, run the
  tests, update the documents, report, then commit.
- **Never commit until the owner approves.**
- **Never claim compatibility not verified:** only the owner's test on
  the real Plus verifies the image; record what is assumed.
- **Never write to the BlueSCSI SD card**, and tell the owner the plan
  before anything touches it.
- **Never change the source WAV files.**
- **Process safety:** external tools with argument arrays, never a shell;
  hfsutils with a private HOME per job.
- **Throwaway diagnostics** in the scratchpad, not the project.
- **No screenshots or Accessibility control** unless the owner asks.
- **Mini vMac:** ask the owner to quit it rather than doing it.
- **The template holds Apple's driver:** never add it to the repository.
