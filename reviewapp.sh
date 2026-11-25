#!/bin/bash
# Usage: ./reviewapp.sh [--preview] <path/to/review.xml> ["App Name"]
#
# Makes a one-click app that opens that review XML in this folder's mpv.app
# (portable_config and its scripts included). Drag it onto the Dock.
# - Needs mpv.app beside this script: run ./appmaker.sh mpv first
# - Lands in ~/Applications (DEST=<folder> puts it somewhere else)
# - Default name: "<the XML's folder> Review"
# - The paths are written into the app, so each Mac makes its own
# - --preview: the app opens it look only (step through versions; no states,
#   notes or Save, and no XML or video written). Run it again without
#   --preview to undo; running it again replaces the app either way

set -euo pipefail

PREVIEW=no
[[ "${1:-}" == "--preview" ]] && { PREVIEW=yes; shift; }
[[ $# -lt 1 ]] && { echo "Usage: ./reviewapp.sh [--preview] <path/to/review.xml> [\"App Name\"]"; exit 1; }

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MPV="$DIR/mpv.app"
[[ -d "$MPV" ]] || { echo "Error: $MPV not found. Run ./appmaker.sh mpv first."; exit 1; }
[[ -f "$1" ]] || { echo "Error: '$1' not found"; exit 1; }
XML="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"

FOLDER="$(basename "$(dirname "$XML")")"
NAME="${2:-$(printf '%s' "${FOLDER:0:1}" | tr '[:lower:]' '[:upper:]')${FOLDER:1} Review}"
SLUG="$(printf '%s' "$NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//')"
DEST="${DEST:-$HOME/Applications}"
APP="$DEST/$NAME.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"

echo "→ Building $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Launcher: the review's path and mpv.app's, quoted for bash
{
    echo '#!/bin/bash'
    echo "# Opens the review XML in the portable mpv. Made by reviewapp.sh."
    printf 'XML=%q\n' "$XML"
    printf 'MPV=%q\n' "$MPV"
    printf 'NAME=%q\n' "$NAME"
    if [[ $PREVIEW == yes ]]; then
        echo 'OPTS=(--script-opts-append=shot_jump-preview=yes)   # look only'
    else
        echo 'OPTS=()'
    fi
    cat <<'LAUNCHER'
alert() { osascript -e 'on run argv' -e 'display alert (item 1 of argv) message (item 2 of argv)' -e 'end run' "$NAME" "$1" >/dev/null; }
if [[ ! -f "$XML" ]]; then
    alert "$(basename "$XML") not found. Is the drive it lives on connected?"
    exit 1
fi
if [[ ! -d "$MPV" ]]; then
    alert "mpv.app not found where it was. Run reviewapp.sh again."
    exit 1
fi
exec open -n -a "$MPV" --args "${OPTS[@]}" "$XML"
LAUNCHER
} > "$APP/Contents/MacOS/launch"
chmod +x "$APP/Contents/MacOS/launch"

# LSUIElement: the launcher hands off to mpv and quits, so it never sits in the Dock itself
PLIST="$APP/Contents/Info.plist"
echo '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict/></plist>' > "$PLIST"
for kv in "CFBundleExecutable=launch" "CFBundleIdentifier=local.review.$SLUG" \
          "CFBundleName=$NAME" "CFBundleDisplayName=$NAME" "CFBundleVersion=1.0" \
          "CFBundleShortVersionString=1.0" "CFBundlePackageType=APPL" "LSMinimumSystemVersion=10.15"; do
    plutil -insert "${kv%%=*}" -string "${kv#*=}" "$PLIST"
done
plutil -insert LSUIElement -bool true "$PLIST"

echo "→ Signing ad-hoc, registering"
codesign --force --deep --sign - "$APP"
"$LSREGISTER" -f "$APP"

echo "✓ $APP"
echo "  Opens: $XML$([[ $PREVIEW == yes ]] && echo "  (look only)")"
echo "  Drag it onto the Dock."
