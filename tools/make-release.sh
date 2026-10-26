#!/bin/sh
# Makes a release of the Macintosh Transfer Utility (Stage 5; R5), from the
# committed source, as the MacMusic Converter Utility's does, into
#   ~/MacPlusProjects/releases/Macintosh-Transfer-Utility-<version>/
# holding:
#   Macintosh-Transfer-Utility-<version>.zip  the app (unzip, drag to Applications)
#   RELEASE-NOTES.md, SHA256SUMS
#   source/MacintoshTransfer.bundle           the whole repository (git bundle, with tags)
#   source/hfsutils-source.tar.gz             the exact source of the bundled hfsutils (GPL)
#   checks/tests.txt, checks/self-test.txt    what was checked, and the results
#   checks/made.txt                           from what, on what
#
# The app holds Apple's driver (in the template), so a release is for its
# owner's own use and is never published (R2).
#
# It refuses a dirty working tree, runs the tests, builds the app with
# hfsutils and the template inside, then runs the self-test on a copy
# outside the repository, with the app's own tools only.
#
# Usage: tools/make-release.sh             a release (candidate)
#        tools/make-release.sh --bundle    after tagging: refresh the source bundle
#                                          (and SHA256SUMS) in the existing release

set -eu
cd "$(dirname "$0")/.."
VERSION=$(sed -n 's/.*static let string = "\(.*\)".*/\1/p' Sources/MacintoshTransferKit/Version.swift)
RETRO68=${MTU_RETRO68_SOURCE:-$HOME/Retro68}
OUT=${MTU_RELEASES:-$HOME/MacPlusProjects/releases}/Macintosh-Transfer-Utility-$VERSION
NAME="Macintosh Transfer Utility"

sums() { (cd "$OUT" && find . -type f ! -name SHA256SUMS | sort | xargs shasum -a 256 > SHA256SUMS); }

if [ "${1:-}" = "--bundle" ]; then
    [ -d "$OUT" ] || { echo "no release at $OUT" >&2; exit 1; }
    git bundle create "$OUT/source/MacintoshTransfer.bundle" --all 2> /dev/null
    git bundle verify "$OUT/source/MacintoshTransfer.bundle" > /dev/null 2>&1
    sums
    echo "refreshed the source bundle: $(git describe --tags --always)"
    exit 0
fi

[ -z "$(git status --porcelain)" ] || { echo "commit (or stash) your changes first: a release is made from committed source" >&2; exit 1; }
[ -z "$(git -C "$RETRO68" status --porcelain hfsutils)" ] || { echo "$RETRO68/hfsutils has local changes: its source wouldn't match the tools" >&2; exit 1; }
[ -e "$OUT" ] && { echo "$OUT already exists: remove it, or change the version" >&2; exit 1; }
mkdir -p "$OUT/source" "$OUT/checks"
COMMIT=$(git rev-parse --short HEAD)
echo "== $NAME $VERSION, from $COMMIT"

echo "== the tests"
tools/test.sh > "$OUT/checks/tests.txt" 2>&1 || { tail -20 "$OUT/checks/tests.txt"; echo "the tests failed" >&2; exit 1; }
grep -E "Test run with" "$OUT/checks/tests.txt"

echo "== the app"
tools/build-app.sh > /dev/null

echo "== the self-test, on a copy outside the repository"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
ditto "build/$NAME.app" "$WORK/$NAME.app"
(cd / && "$WORK/$NAME.app/Contents/MacOS/MacintoshTransfer" --self-test) > "$OUT/checks/self-test.txt" 2>&1 \
    || { cat "$OUT/checks/self-test.txt"; echo "the self-test failed" >&2; exit 1; }
tail -1 "$OUT/checks/self-test.txt"

echo "== packaging"
ditto -c -k --keepParent "build/$NAME.app" "$OUT/Macintosh-Transfer-Utility-$VERSION.zip"
cp Documentation/RELEASE-NOTES.md "$OUT/RELEASE-NOTES.md"
git bundle create "$OUT/source/MacintoshTransfer.bundle" --all 2> /dev/null
git bundle verify "$OUT/source/MacintoshTransfer.bundle" > /dev/null 2>&1
git -C "$RETRO68" archive --format=tar.gz --prefix=Retro68/ -o "$OUT/source/hfsutils-source.tar.gz" HEAD hfsutils
RETRO68_COMMIT=$(git -C "$RETRO68" rev-parse --short HEAD)
{
    echo "$NAME $VERSION, made $(date '+%Y-%m-%d %H:%M') from commit $COMMIT ($(git describe --tags --always))"
    echo "on $(sw_vers -productName) $(sw_vers -productVersion), $(sysctl -n hw.model), $(xcodebuild -version 2>/dev/null | head -1), $(swift --version 2>&1 | head -1)"
    echo "hfsutils: Retro68's, from its commit $RETRO68_COMMIT (source/hfsutils-source.tar.gz)"
    echo "template: $(shasum -a 256 "build/$NAME.app/Contents/Resources/bluescsi-template.hda" | cut -d' ' -f1)"
} > "$OUT/checks/made.txt"
sums
echo "== done: $OUT"
ls -l "$OUT"
du -sh "$OUT"
