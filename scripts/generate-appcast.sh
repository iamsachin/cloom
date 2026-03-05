#!/bin/bash
set -euo pipefail

# Generates/updates appcast.xml for Sparkle auto-updates.
#
# Usage:
#   ./scripts/generate-appcast.sh <version> <dmg-path> <ed-signature> <dmg-size> [output-dir]
#
# Example:
#   ./scripts/generate-appcast.sh 0.2.0 build/Cloom-0.2.0.dmg "BASE64SIG" 45678901

VERSION="$1"
DMG_PATH="$2"
ED_SIGNATURE="$3"
DMG_SIZE="$4"

DOWNLOAD_URL="https://github.com/iamsachin/cloom/releases/download/v${VERSION}/Cloom-${VERSION}.dmg"
PUB_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S +0000")

APPCAST_DIR="${5:-.}"
APPCAST_FILE="${APPCAST_DIR}/appcast.xml"

# Write the new <item> block to a temp file
ITEM_FILE=$(mktemp)
cat > "$ITEM_FILE" <<ITEM_EOF
        <item>
            <title>Version ${VERSION}</title>
            <pubDate>${PUB_DATE}</pubDate>
            <sparkle:version>${VERSION}</sparkle:version>
            <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
            <enclosure
                url="${DOWNLOAD_URL}"
                sparkle:edSignature="${ED_SIGNATURE}"
                length="${DMG_SIZE}"
                type="application/octet-stream" />
        </item>
ITEM_EOF

if [ -f "$APPCAST_FILE" ]; then
    # Insert new item before the closing </channel> tag
    TEMP_FILE=$(mktemp)
    while IFS= read -r line; do
        if [[ "$line" == *"</channel>"* ]]; then
            cat "$ITEM_FILE"
        fi
        printf '%s\n' "$line"
    done < "$APPCAST_FILE" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$APPCAST_FILE"
else
    # Create fresh appcast
    cat > "$APPCAST_FILE" <<APPCAST_EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>Cloom Updates</title>
        <link>https://iamsachin.github.io/cloom/appcast.xml</link>
        <description>Cloom app updates</description>
        <language>en</language>
$(cat "$ITEM_FILE")
    </channel>
</rss>
APPCAST_EOF
fi

rm -f "$ITEM_FILE"
echo "Appcast updated: ${APPCAST_FILE}"
