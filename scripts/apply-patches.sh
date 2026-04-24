#!/bin/bash
set -e

echo "=== CyberBrowser: Apply Patches ==="

CHROMIUM_ROOT="${CHROMIUM_ROOT:-$HOME/chromium}"
SRC_DIR="$CHROMIUM_ROOT/src"
PATCH_DIR="$(cd "$(dirname "$0")/../patches" && pwd)"

if [ ! -d "$SRC_DIR" ]; then
    echo "ERROR: Chromium source not found at $SRC_DIR"
    echo "Run fetch-chromium.sh first"
    exit 1
fi

cd "$SRC_DIR"

# Backup original files
if [ ! -f "ios/web/shell/view_controller.mm.bak" ]; then
    echo "Backing up original view_controller.mm..."
    cp ios/web/shell/view_controller.mm ios/web/shell/view_controller.mm.bak
fi

# Apply CyberBrowser patches
echo "Applying CyberBrowser UI patches..."
if [ -f "$PATCH_DIR/view_controller_tabbed.patch" ]; then
    # Apply the patch (this is a simplified approach - in CI we'd use patch command)
    cp "$PATCH_DIR/CyberBrowserViewController.mm.patch" ios/web/shell/view_controller.mm
    echo "Patched view_controller.mm"
else
    echo "WARNING: Patches not found, using original Chromium shell UI"
fi

# Modify app_delegate to use our custom name if needed
# (Currently we keep the original since it just initializes WebMain)

echo "Patches applied successfully"
