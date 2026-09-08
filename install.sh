#!/bin/sh
set -eu

REPO="longnt27/lookaway"
MANIFEST="https://github.com/${REPO}/releases/latest/download/latest.json"
DEST_DIR="${LOOKAWAY_INSTALL_DIR:-$HOME/Applications}"
APP="$DEST_DIR/LookAway.app"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/lookaway-install.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT INT TERM

if [ "$(uname -s)" != "Darwin" ]; then
  echo "LookAway requires macOS." >&2
  exit 1
fi

mkdir -p "$DEST_DIR"

echo "Fetching latest LookAway release..."
curl -fsSL "$MANIFEST" -o "$TMP/latest.json"
VERSION="$(plutil -extract version raw -o - "$TMP/latest.json")"
URL="$(plutil -extract url raw -o - "$TMP/latest.json")"
EXPECTED="$(plutil -extract sha256 raw -o - "$TMP/latest.json")"
ZIP="$TMP/LookAway.zip"

case "$URL" in
  https://github.com/${REPO}/releases/download/*) ;;
  *) echo "Refusing unexpected download URL: $URL" >&2; exit 1 ;;
esac

curl -fL --retry 3 --proto '=https' --tlsv1.2 "$URL" -o "$ZIP"
ACTUAL="$(shasum -a 256 "$ZIP" | awk '{print $1}')"
if [ "$ACTUAL" != "$EXPECTED" ]; then
  echo "Checksum verification failed." >&2
  exit 1
fi

mkdir -p "$TMP/unpacked"
/usr/bin/ditto -x -k "$ZIP" "$TMP/unpacked"
NEW_APP="$TMP/unpacked/LookAway.app"
if [ ! -x "$NEW_APP/Contents/MacOS/LookAway" ]; then
  echo "Release does not contain a valid LookAway.app." >&2
  exit 1
fi

# Stop an installed copy before replacing it. Ignore failure when it is not running.
/usr/bin/pkill -x LookAway >/dev/null 2>&1 || true
sleep 0.3
rm -rf "$APP"
/usr/bin/ditto "$NEW_APP" "$APP"

printf '\nInstalled LookAway %s to %s\n' "$VERSION" "$APP"
/usr/bin/open "$APP"
echo "LookAway is running from your menu bar."
