#!/bin/bash
# ==============================================================================
# Fatih Kalem Linux Automated Installer
# Works on Fedora, Debian, Ubuntu, Arch Linux and derived distributions.
# Compatible with Intel/AMD/Nvidia GPUs and modern desktop environments.
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSUME_YES=false

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -y|--yes) ASSUME_YES=true ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -y, --yes      Automatic mode (accept all defaults without prompting)"
            echo "  -h, --help     Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
    shift
done

echo "=========================================================="
echo "          Fatih Kalem Linux Automated Installer           "
echo "=========================================================="
echo ""

# Determine privilege helper
SUDO=""
if [ "$EUID" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    else
        echo "Error: Root privileges are required. Please run with sudo or install sudo." >&2
        exit 1
    fi
fi

# Detect package manager
PKG_MGR=""
if command -v dnf >/dev/null 2>&1; then
    PKG_MGR="dnf"
elif command -v apt-get >/dev/null 2>&1; then
    PKG_MGR="apt"
elif command -v pacman >/dev/null 2>&1; then
    PKG_MGR="pacman"
fi

echo "[1/6] Checking Wine prerequisites..."
if ! command -v wine >/dev/null 2>&1; then
    echo "Wine is not installed. Installing Wine..."
    case "$PKG_MGR" in
        dnf)
            $SUDO dnf install -y wine wine-mono
            ;;
        apt)
            $SUDO apt-get update
            $SUDO apt-get install -y wine wine64 wine-mono-package || $SUDO apt-get install -y wine
            ;;
        pacman)
            $SUDO pacman -Sy --noconfirm wine wine-mono
            ;;
        *)
            echo "Warning: Unsupported package manager. Please ensure 'wine' and 'wine-mono' are installed." >&2
            ;;
    esac
else
    echo "✓ Wine is installed ($(wine --version))."
fi

# Initialize Wine prefix if not already created
export WINEPREFIX="${WINEPREFIX:-$HOME/.wine}"
echo "[2/6] Initializing Wine prefix at $WINEPREFIX..."
wineboot -u
# Wait for wineserver to settle
wineserver -w || true

echo "[3/6] Patching Wine-Mono with Microsoft WPF Core Runtime..."
# Locate wine-mono directories
MONO_DIRS=(/usr/share/wine/mono/wine-mono-*)
if [ ${#MONO_DIRS[@]} -eq 0 ] || [ ! -d "${MONO_DIRS[0]}" ]; then
    echo "Wine-Mono not found in /usr/share/wine/mono. Installing wine-mono..."
    if [ "$PKG_MGR" = "dnf" ]; then
        $SUDO dnf install -y wine-mono
    fi
    MONO_DIRS=(/usr/share/wine/mono/wine-mono-*)
fi

for MONO_DIR in "${MONO_DIRS[@]}"; do
    if [ -d "$MONO_DIR" ]; then
        echo "Patching Wine-Mono at $MONO_DIR..."
        
        # Backup original wpfgfx if not already backed up
        if [ ! -f "$MONO_DIR/lib/x86/wpfgfx_cor3.dll.orig" ] && [ -f "$MONO_DIR/lib/x86/wpfgfx_cor3.dll" ]; then
            $SUDO cp "$MONO_DIR/lib/x86/wpfgfx_cor3.dll" "$MONO_DIR/lib/x86/wpfgfx_cor3.dll.orig"
        fi
        if [ ! -f "$MONO_DIR/lib/x86_64/wpfgfx_cor3.dll.orig" ] && [ -f "$MONO_DIR/lib/x86_64/wpfgfx_cor3.dll" ]; then
            $SUDO cp "$MONO_DIR/lib/x86_64/wpfgfx_cor3.dll" "$MONO_DIR/lib/x86_64/wpfgfx_cor3.dll.orig"
        fi

        # Install 64-bit WPF Core native binaries
        $SUDO cp -v "$SCRIPT_DIR/assets/wpf-native/x64/"* "$MONO_DIR/lib/x86_64/"
        $SUDO cp -v "$SCRIPT_DIR/assets/wpf-native/x64/"* "$MONO_DIR/bin/"

        # Install 32-bit WPF Core native binaries
        $SUDO cp -v "$SCRIPT_DIR/assets/wpf-native/x86/"* "$MONO_DIR/lib/x86/"
    fi
done

# Also ensure WPF Core native libraries are present inside user Wine prefix
mkdir -p "$WINEPREFIX/drive_c/windows/system32" "$WINEPREFIX/drive_c/windows/syswow64"
cp -v "$SCRIPT_DIR/assets/wpf-native/x64/"* "$WINEPREFIX/drive_c/windows/system32/" 2>/dev/null || true
cp -v "$SCRIPT_DIR/assets/wpf-native/x86/"* "$WINEPREFIX/drive_c/windows/syswow64/" 2>/dev/null || true

echo "[4/6] Applying Direct3D / OpenGL graphics compatibility fixes..."
# Intel HD Graphics 3000 (Sandy Bridge) does not support Vulkan in hardware.
# On Fedora, switch update-alternatives to native WineD3D (OpenGL) instead of DXVK
if command -v update-alternatives >/dev/null 2>&1; then
    for alt in 'wine-d3d9(x86-64)' 'wine-d3d11(x86-64)' 'wine-dxgi(x86-64)' 'wine-d3d10core(x86-64)' 'wine-d3d8(x86-64)'; do
        target=$(update-alternatives --display "$alt" 2>/dev/null | grep -E "wine-d3d|wine-dxgi" | grep -v "dxvk" | awk '{print $1}' | head -n 1 || true)
        if [ -n "$target" ] && [ -f "$target" ]; then
            $SUDO update-alternatives --set "$alt" "$target" 2>/dev/null || true
        fi
    done
fi

# Configure Avalon software rendering fallback in Wine registry
wine reg add "HKEY_CURRENT_USER\\Software\\Microsoft\\Avalon.Graphics" /v "DisableHWAcceleration" /t REG_DWORD /d 1 /f >/dev/null 2>&1 || true

echo "[5/6] Locating and installing Fatih Kalem..."
INSTALLER=""
CANDIDATES=(
    "$SCRIPT_DIR/fatihkalem_setup.exe"
    "$HOME/Downloads/fatihkalem_setup.exe"
    "/home/yazilimodasi/Downloads/fatihkalem_setup.exe"
)

for c in "${CANDIDATES[@]}"; do
    if [ -f "$c" ]; then
        INSTALLER="$c"
        break
    fi
done

if [ -z "$INSTALLER" ]; then
    echo "fatihkalem_setup.exe not found locally. Attempting to download..."
    DOWNLOAD_URL="https://fatihprojesi.meb.gov.tr/fatihkalem/fatihkalem_setup.exe"
    if curl -fksSL "$DOWNLOAD_URL" -o "$SCRIPT_DIR/fatihkalem_setup.exe"; then
        INSTALLER="$SCRIPT_DIR/fatihkalem_setup.exe"
    else
        echo "Error: Could not find or download fatihkalem_setup.exe." >&2
        echo "Please download fatihkalem_setup.exe and place it in $HOME/Downloads/ or $SCRIPT_DIR/ and re-run this script." >&2
        exit 1
    fi
fi

echo "Running Fatih Kalem silent installation from $INSTALLER..."
wine "$INSTALLER" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-
wineserver -w || true

# Clean up any stray dll files from the app directory that could conflict
APP_DIR="$WINEPREFIX/drive_c/Program Files (x86)/Fatih Kalem"
if [ -d "$APP_DIR" ]; then
    rm -f "$APP_DIR/iconv.dll" "$APP_DIR/MSVCR120_CLR0400.dll" "$APP_DIR/PresentationCore.dll" \
          "$APP_DIR/PresentationFramework.dll" "$APP_DIR/WindowsBase.dll" \
          "$APP_DIR/wpfgfx_cor3.dll" "$APP_DIR/wpfgfx_v0400.dll" "$APP_DIR/Fatih Kalem.exe.config"
fi

echo "[6/6] Installing desktop launcher, system CLI wrapper and icon..."
# Install CLI wrapper
$SUDO cp -v "$SCRIPT_DIR/fatih-kalem" /usr/local/bin/fatih-kalem
$SUDO chmod +x /usr/local/bin/fatih-kalem

# Install icons
$SUDO mkdir -p /usr/share/icons/hicolor/256x256/apps
$SUDO cp -v "$SCRIPT_DIR/assets/fatih-kalem.png" /usr/share/icons/hicolor/256x256/apps/fatih-kalem.png
mkdir -p "$HOME/.local/share/icons/hicolor/256x256/apps"
cp -v "$SCRIPT_DIR/assets/fatih-kalem.png" "$HOME/.local/share/icons/hicolor/256x256/apps/fatih-kalem.png"

# Install desktop shortcut
$SUDO mkdir -p /usr/share/applications
$SUDO cp -v "$SCRIPT_DIR/assets/fatih-kalem.desktop" /usr/share/applications/fatih-kalem.desktop
mkdir -p "$HOME/.local/share/applications" "$HOME/Desktop"
cp -v "$SCRIPT_DIR/assets/fatih-kalem.desktop" "$HOME/.local/share/applications/fatih-kalem.desktop"
cp -v "$SCRIPT_DIR/assets/fatih-kalem.desktop" "$HOME/Desktop/Fatih Kalem.desktop"
chmod +x "$HOME/Desktop/Fatih Kalem.desktop"

# Refresh desktop databases
$SUDO update-desktop-database /usr/share/applications/ 2>/dev/null || true
update-desktop-database "$HOME/.local/share/applications/" 2>/dev/null || true
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    $SUDO gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true
fi

# Ensure clean wineserver shutdown
wineserver -k 2>/dev/null || true

echo ""
echo "=========================================================="
echo "    ✓ Fatih Kalem has been successfully installed!        "
echo "=========================================================="
echo ""
echo "You can launch Fatih Kalem anytime by:"
echo "  1. Double-clicking the 'Fatih Kalem' shortcut on your Desktop"
echo "  2. Searching for 'Fatih Kalem' in your Applications menu"
echo "  3. Running 'fatih-kalem' in your terminal"
echo ""
