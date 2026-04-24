#!/bin/bash
set -e

echo "=== CyberBrowser: Fetch Chromium iOS Source ==="

CHROMIUM_ROOT="${CHROMIUM_ROOT:-$HOME/chromium}"
DEPOT_TOOLS="${DEPOT_TOOLS:-$CHROMIUM_ROOT/depot_tools}"
SRC_DIR="$CHROMIUM_ROOT/src"

# Install depot_tools
if [ ! -d "$DEPOT_TOOLS" ]; then
    echo "[1/5] Cloning depot_tools..."
    git clone --depth=1 https://chromium.googlesource.com/chromium/tools/depot_tools.git "$DEPOT_TOOLS"
fi

export PATH="$DEPOT_TOOLS:$PATH"

# Fetch Chromium iOS source
if [ ! -d "$SRC_DIR" ]; then
    echo "[2/5] Fetching Chromium iOS source (this takes ~30-60 min)..."
    mkdir -p "$CHROMIUM_ROOT"
    cd "$CHROMIUM_ROOT"
    fetch --nohooks ios
else
    echo "[2/5] Syncing existing Chromium source..."
    cd "$SRC_DIR"
    gclient sync
fi

cd "$SRC_DIR"

# Install build dependencies
echo "[3/5] Installing iOS build dependencies..."
./build/install-build-deps-ios.sh 2>/dev/null || true

# Run hooks (downloads prebuilt binaries, generates build files)
echo "[4/5] Running gclient hooks..."
gclient runhooks

# Configure build for iOS content_shell
echo "[5/5] Configuring build args..."
mkdir -p out/CyberBrowser-Release

cat > out/CyberBrowser-Release/args.gn << 'EOF'
# CyberBrowser build configuration
is_debug = false
is_component_build = false
ios_enable_code_signing = false
ios_deployment_target = "15.0"
target_os = "ios"
target_cpu = "arm64"
use_blink = true
v8_use_external_startup_data = false
enable_ios_webview = true
symbol_level = 0
strip_debug_info = true
EOF

gn gen out/CyberBrowser-Release

echo ""
echo "=== Chromium source ready ==="
echo "Build directory: $SRC_DIR/out/CyberBrowser-Release"
echo ""
echo "To build ios_web_shell:"
echo "  cd $SRC_DIR"
echo "  autoninja -C out/CyberBrowser-Release ios_web_shell"
echo ""
