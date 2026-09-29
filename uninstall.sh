#!/bin/bash
# Fatih Kalem Linux Uninstaller
set -e

echo "=========================================================="
echo "          Fatih Kalem Linux Uninstaller                  "
echo "=========================================================="

SUDO=""
if [ "$EUID" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    else
        echo "Root privileges are required to remove system files." >&2
        exit 1
    fi
fi

echo "[1/4] Removing system launcher and shortcuts..."
$SUDO rm -f /usr/local/bin/fatih-kalem
$SUDO rm -f /usr/share/applications/fatih-kalem.desktop
$SUDO rm -f /usr/share/icons/hicolor/256x256/apps/fatih-kalem.png

rm -f "$HOME/Desktop/Fatih Kalem.desktop"
rm -f "$HOME/.local/share/applications/Fatih Kalem.desktop"
rm -f "$HOME/.local/share/applications/fatih-kalem.desktop"

echo "[2/4] Uninstalling Windows application from Wine..."
WINEPREFIX="${WINEPREFIX:-$HOME/.wine}"
UNINSTALLER="$WINEPREFIX/drive_c/Program Files (x86)/Fatih Kalem/unins000.exe"

if [ -f "$UNINSTALLER" ]; then
    echo "Running silent uninstaller..."
    wine "$UNINSTALLER" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART || true
    sleep 2
fi

rm -rf "$WINEPREFIX/drive_c/Program Files (x86)/Fatih Kalem"

echo "[3/4] Restoring Wine-Mono original libraries if backed up..."
for orig in /usr/share/wine/mono/wine-mono-*/lib/x86_64/wpfgfx_cor3.dll.orig; do
    if [ -f "$orig" ]; then
        target="${orig%.orig}"
        $SUDO cp -v "$orig" "$target" 2>/dev/null || true
    fi
done

echo "[4/4] Updating desktop database and icon caches..."
$SUDO update-desktop-database /usr/share/applications/ 2>/dev/null || true
update-desktop-database "$HOME/.local/share/applications/" 2>/dev/null || true
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    $SUDO gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true
fi

echo ""
echo "Fatih Kalem uninstalled successfully."
