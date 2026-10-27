#!/bin/bash
# Installs a LaunchAgent that automatically strips com.apple.quarantine
# from files in a watched folder the moment new files appear.
#
# Usage: ./watch-unquarantine.sh <directory>
# Example: ./watch-unquarantine.sh ~/Movies/Captures

set -euo pipefail

[[ $# -eq 0 ]] && { echo "Usage: ./watch-unquarantine.sh <directory>"; exit 1; }

WATCH_DIR="$(cd "$1" && pwd)"
LABEL="local.unquarantine.$(basename "$WATCH_DIR")"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"

mkdir -p "$HOME/Library/LaunchAgents"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>xattr -r -d com.apple.quarantine "${WATCH_DIR}" 2>/dev/null; true</string>
    </array>
    <key>WatchPaths</key>
    <array>
        <string>${WATCH_DIR}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"

echo "✓ Watching: $WATCH_DIR"
echo "  Quarantine will be stripped automatically whenever files are added."
echo ""
echo "  To stop:    launchctl unload '$PLIST'"
echo "  To remove:  rm '$PLIST'"
