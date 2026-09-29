#!/bin/bash
# Renders guide.html to a PDF with headless Chrome.
#   ./build.sh [output.pdf]
# Default output : ~/Downloads/OpenCutList-quincailleries-personnalisees.pdf
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$HOME/Downloads/OpenCutList-quincailleries-personnalisees.pdf}"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
VERSION="$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$DIR/../../build/package.json" | head -1)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# {{DATE}} and {{VERSION}} are filled at build time
sed -e "s/{{DATE}}/$(date +%Y-%m-%d)/g" -e "s/{{VERSION}}/$VERSION/g" "$DIR/guide.html" > "$TMP/guide.html"

"$CHROME" --headless=new --disable-gpu --no-pdf-header-footer \
  --print-to-pdf="$OUT" "file://$TMP/guide.html" 2>/dev/null

echo "$OUT"
