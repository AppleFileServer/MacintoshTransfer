#!/bin/sh
# Builds "MacMusic Transfer Utility.app" in build/ (Stage 3): the release
# build of the app in a bundle with its Info.plist, signed ad hoc. (Stage 5
# adds hfsutils and the template inside it.)
#
# Usage: tools/build-app.sh

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
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
echo "built $APP ($VERSION)"
