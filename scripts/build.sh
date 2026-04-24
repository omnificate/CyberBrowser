#!/bin/bash
set -e

echo "=== CyberBrowser: Build ==="

CHROMIUM_ROOT="${CHROMIUM_ROOT:-$HOME/chromium}"
SRC_DIR="$CHROMIUM_ROOT/src"
OUTPUT_DIR="${OUTPUT_DIR:-$PWD/build-output}"

cd "$SRC_DIR"

# Build ios_web_shell (the content_shell target with our patches)
echo "Building ios_web_shell (this will take 2-6 hours on first run)..."
autoninja -C out/CyberBrowser-Release ios_web_shell

echo "Build complete!"

# Package the output
mkdir -p "$OUTPUT_DIR"

if [ -d "out/CyberBrowser-Release/ios_web_shell.app" ]; then
    echo "Found ios_web_shell.app"
    cp -R "out/CyberBrowser-Release/ios_web_shell.app" "$OUTPUT_DIR/CyberBrowser.app"
    echo "Packaged: $OUTPUT_DIR/CyberBrowser.app"
fi

# List output
echo ""
echo "=== Build Output ==="
ls -la "$OUTPUT_DIR/"
