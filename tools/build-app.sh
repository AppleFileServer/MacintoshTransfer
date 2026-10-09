#!/bin/sh
# Builds "MacMusic Transfer Utility.app" in build/ (Stage 3): the release
# build of the app in a bundle with its Info.plist, signed ad hoc, with
# (Stage 5; R1, R2) inside it:
#   Contents/Helpers/hfsutils/   Retro68's hfsutils, the 8 tools used;
#   Contents/Resources/hfsutils/ its COPYING and COPYRIGHT (GPL)
#   Contents/Resources/bluescsi-template.hda
#                                the template's 96 blocks (Apple's driver:
#                                never added to the repository)
#
# Usage: tools/build-app.sh   (MTU_HFSUTILS_BUILD, MTU_TEMPLATE to override)

set -eu
cd "$(dirname "$0")/.."
SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
export SDKROOT
VERSION=$(sed -n 's/.*static let string = "\(.*\)".*/\1/p' Sources/MacMusicTransferKit/Version.swift)
swift build -c release --product MacMusicTransfer
BIN=$(swift build -c release --show-bin-path)/MacMusicTransfer
APP="build/MacMusic Transfer Utility.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MacMusicTransfer"
sed "s/@VERSION@/$VERSION/g" Resources/Info.plist > "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"

HFS=${MTU_HFSUTILS_BUILD:-$HOME/Retro68-build/toolchain/bin}
HFSSRC=${MTU_HFSUTILS_SOURCE:-$HOME/Retro68/hfsutils}
TEMPLATE=${MTU_TEMPLATE:-$HOME/MacPlusProjects/environment-1.0/bluescsi-template.hda}
mkdir -p "$APP/Contents/Helpers/hfsutils"
for tool in hformat hmount humount hmkdir hcopy hattrib hls hvol; do
    cp -pL "$HFS/$tool" "$APP/Contents/Helpers/hfsutils/$tool"
done
mkdir -p "$APP/Contents/Resources/hfsutils"
cp "$HFSSRC/COPYING" "$HFSSRC/COPYRIGHT" "$APP/Contents/Resources/hfsutils/"
head -c 49152 "$TEMPLATE" > "$APP/Contents/Resources/bluescsi-template.hda"
[ "$(wc -c < "$APP/Contents/Resources/bluescsi-template.hda")" -eq 49152 ] || { echo "the template is too short" >&2; exit 1; }
codesign --force --sign - "$APP"/Contents/Helpers/hfsutils/h*
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
echo "built $APP ($VERSION)"
