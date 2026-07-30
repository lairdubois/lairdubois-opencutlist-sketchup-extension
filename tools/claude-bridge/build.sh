#!/usr/bin/env bash
#
# Packages the Claude Bridge extension into an installable .rbz, with the
# documentation rendered to PDF.
#
# The PDF is printed from doc/claude-bridge.html by headless Chrome (the only
# HTML-to-PDF engine we can count on being installed on macOS).
#
# Usage: tools/claude-bridge/build.sh
# Output: tools/claude-bridge/dist/claude-bridge-<version>.rbz

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST="$HERE/dist"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# Version comes from the registrar, so there is a single source of truth
VERSION="$(sed -n "s/.*ex\.version *= *'\([^']*\)'.*/\1/p" "$HERE/claude_bridge.rb")"
[ -n "$VERSION" ] || { echo "Could not read ex.version from claude_bridge.rb" >&2; exit 1; }

RBZ="$DIST/claude-bridge-$VERSION.rbz"

# ----- Documentation

[ -x "$CHROME" ] || { echo "Google Chrome not found at $CHROME (needed to render the PDF)" >&2; exit 1; }

echo "Rendering doc/claude-bridge.html -> claude_bridge/doc/claude-bridge.pdf"
mkdir -p "$STAGE/claude_bridge/doc"
"$CHROME" \
  --headless \
  --disable-gpu \
  --no-pdf-header-footer \
  --print-to-pdf="$STAGE/claude_bridge/doc/claude-bridge.pdf" \
  "file://$HERE/doc/claude-bridge.html" 2>/dev/null

[ -s "$STAGE/claude_bridge/doc/claude-bridge.pdf" ] || { echo "PDF rendering produced no output" >&2; exit 1; }

# ----- Payload

cp "$HERE/claude_bridge.rb" "$STAGE/"
cp "$HERE/claude_bridge/main.rb" "$STAGE/claude_bridge/"
cp -R "$HERE/claude_bridge/icons" "$STAGE/claude_bridge/"

# ----- Archive

mkdir -p "$DIST"
rm -f "$RBZ"
( cd "$STAGE" && zip -q -r -X "$RBZ" claude_bridge.rb claude_bridge )

echo
echo "Built $RBZ"
unzip -l "$RBZ" | sed '1,3d;$d'
