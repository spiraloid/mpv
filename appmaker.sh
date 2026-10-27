#!/bin/bash
# Usage: ./appmaker.sh <binary>
#
# Wraps a CLI binary as a macOS .app bundle.
# - If portable_config/ exists next to the binary, passes --config-dir at launch
# - If <binary>.plist exists next to this script, merges it into Info.plist
#   (use it to declare CFBundleDocumentTypes for "Open With" / default app support)
# - Signs ad-hoc by default. For Developer ID signing + notarization:
#     SIGN_ID="Developer ID Application: Name (TEAMID)" NOTARY_PROFILE=mpv-notary ./appmaker.sh <binary>
#   (NOTARY_PROFILE comes from: xcrun notarytool store-credentials <profile> ...)

set -euo pipefail

[[ $# -eq 0 ]] && { echo "Usage: ./appmaker.sh <binary>"; exit 1; }

BINARY="$1"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$DIR/${BINARY}.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"

[[ ! -f "$DIR/$BINARY" ]] && { echo "Error: '$BINARY' not found in $DIR"; exit 1; }

echo "→ Building ${BINARY}.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Launcher — resolves paths at runtime so the folder can be freely moved
cat > "$APP/Contents/MacOS/$BINARY" <<LAUNCHER
#!/bin/bash
S="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
R="\$(dirname "\$(dirname "\$(dirname "\$S")")")"
ARGS=()
[[ -d "\$R/portable_config" ]] && ARGS+=(--config-dir="\$R/portable_config")
# Finder passes files as Apple Events, not argv; pseudo-gui keeps mpv alive to receive them
[[ \$# -eq 0 && "$BINARY" == mpv ]] && ARGS+=(--player-operation-mode=pseudo-gui)
xattr -d com.apple.quarantine "\$@" 2>/dev/null || true
exec "\$R/$BINARY" "\${ARGS[@]}" "\$@"
LAUNCHER
chmod +x "$APP/Contents/MacOS/$BINARY" "$DIR/$BINARY"

# Base Info.plist
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable       string $BINARY"         \
                         -c "Add :CFBundleIdentifier      string local.$BINARY"   \
                         -c "Add :CFBundleName            string $BINARY"         \
                         -c "Add :CFBundleDisplayName     string $BINARY"         \
                         -c "Add :CFBundleVersion         string 1.0"             \
                         -c "Add :CFBundleShortVersionString string 1.0"          \
                         -c "Add :CFBundlePackageType     string APPL"            \
                         -c "Add :LSMinimumSystemVersion  string 10.15"           \
                         -c "Add :NSHighResolutionCapable bool   true"            \
                         "$APP/Contents/Info.plist"

# Merge extra keys (document types, UTIs, etc.) from <binary>.plist if present
[[ -f "$DIR/${BINARY}.plist" ]] && {
    echo "→ Merging ${BINARY}.plist"
    /usr/libexec/PlistBuddy -c "Merge '$DIR/${BINARY}.plist'" "$APP/Contents/Info.plist"
}

if [[ -n "${SIGN_ID:-}" ]]; then
    # Developer ID + notarization: lets Finder open downloaded/quarantined files with this app
    echo "→ Signing with $SIGN_ID"
    codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$APP"
    if [[ -n "${NOTARY_PROFILE:-}" ]]; then
        echo "→ Notarizing (profile: $NOTARY_PROFILE)"
        ZIP="$(mktemp -d)/${BINARY}.zip"
        ditto -c -k --keepParent "$APP" "$ZIP"
        xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
        xcrun stapler staple "$APP"
    fi
else
    echo "→ Signing ad-hoc"
    codesign --force --deep --sign - "$APP"
fi

echo "→ Clearing quarantine, registering"
xattr -r -d com.apple.quarantine "$APP" "$DIR/$BINARY" 2>/dev/null || true
"$LSREGISTER" -f "$APP"

echo "✓ $APP"
