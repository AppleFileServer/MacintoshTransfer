# Building

## The environment (2026-10-09)

MacBook Neo (Mac17,5), macOS 26.4.1, Xcode 26.6 (SDK 26.5), Swift 6.3.3.
`xcrun`'s default SDK lookup fails on this Mac: the scripts set
`SDKROOT=$(xcrun --sdk macosx --show-sdk-path)`.

## External pieces

| What | Where | Notes |
|---|---|---|
| hfsutils 3.2.6 | `~/Retro68-build/toolchain/bin` (Retro68's build; source `~/Retro68/hfsutils`) | GPL v2; inside the app from Stage 5 |
| The template | `~/MacPlusProjects/environment-1.0/bluescsi-template.hda` (MacMusic's environment archive) | Apple's driver: never in the repository |
| machfs 1.3 (tests) | `~/MacPlusProjects/transfer-tools/venv` | MIT; the tests skip it if absent |

To make machfs's venv again:

    python3 -m venv ~/MacPlusProjects/transfer-tools/venv
    ~/MacPlusProjects/transfer-tools/venv/bin/pip install machfs==1.3

## The icon

`Resources/Icon/AppIcon.svg`; `tools/make-icon.sh` remakes
`Resources/AppIcon.icns` (headless Chrome from the MacMusic manual's
tools, sips, iconutil), kept in the repository.

## Commands

    tools/test.sh
    swift build -c release --product mtu-build        # with SDKROOT set, as above
    .build/release/mtu-build [--id N] [--replace] <output folder> <file.wav> ...

It shows each file's check and Mac name, the size and its working, the
stages, and the summary. An existing image is kept: the new one is named
`… Transfer 2.hda` (`--replace` replaces it).
