# MacMusic Transfer Utility 1.0

A Mac app that puts MacMusic WAV files on a disk for a Macintosh Plus: it
packages them into a BlueSCSI device image, ready to copy to the
BlueSCSI's SD card.

## Installing

Unzip `MacMusic-Transfer-Utility-1.0.zip` and drag **MacMusic Transfer
Utility** to Applications. Everything it needs is inside it (hfsutils and
the disk template). It needs an Apple silicon Mac with macOS 26.

It's signed ad hoc, for its owner's own use; not notarised. If macOS
won't open it the first time, open System Settings, click Privacy &
Security, and click Open Anyway beside its name (since macOS 15,
Control-click and Open no longer does it). The disk template inside it
holds Apple's driver, so the app isn't for passing on.

## Using it

1. Drop WAV files (or a folder of them: its WAVs, one level) in the
   window. Each is checked against MacMusic's own rules: mono, 22,050 Hz,
   8-bit. Anything else is refused; convert it with the MacMusic
   Converter Utility first.
2. Choose the SCSI ID (6 unless you change it) and, if you like, the
   image's file name, then **Build Transfer Image**. The size is worked out for
   you: the files, plus a quarter for adding more, plus 4 MB.
3. The image is checked before it's kept, and saved to
   `~/Music/MacMusic Transfer` unless you choose another folder:
   `HD60_512 Transfer.hda`, for instance.
4. Copy the image to the BlueSCSI's SD card yourself, with the Plus
   switched off. The app never writes to the card.
5. On the Plus, the disk **Transfer** holds a folder **WAV Files**;
   import the songs with MacMusic's File > Import Song.

Names are changed to suit the Mac where they must be: at most 31
characters, no colons, and no two names alike ignoring case (a second
"clash.wav" becomes "clash 2.wav"). The window shows each new name.

## Checked

On the owner's Macintosh Plus, System 6.0.7, BlueSCSI: an image made
this way mounts, with its WAV files there (2026-10-09); and (2026-10-26)
a test set's names came through as shown when it was built (Café, a
shortened long name, a colon, a case clash), and songs from it and from
an image made by this release imported into MacMusic and played.
Nothing else has been tried; other Macs, systems and SCSI emulators may
well work but aren't claimed.

## Safe with your files

It never changes the source WAVs; it asks before replacing an image;
nothing half-made is left behind, even when you cancel, quit or the disk
fills mid-build; and what it leaves after a crash is cleared the next
time it starts.

## Bundled software

hfsutils 3.2.6 (GPL v2), as built by Retro68: its licence is in the app
at `Contents/Resources/hfsutils`, and its source comes with the release.

## Known limits

- One image per SCSI ID on the card: make sure no other image uses the
  same ID. ID 7 is the Mac itself; ID 0 is usually its startup disk.
- Folders are added one level deep; the disk holds one folder.
- Images of up to 2 GB.
