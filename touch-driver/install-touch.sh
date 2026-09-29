#!/bin/bash
# Faz 1 Smart Board Touchscreen (IRTOUCHSYSTEMS 6615:0c20) Installer
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root (use sudo)." >&2
    exit 1
fi

echo "=========================================================="
echo "    Faz 1 Smart Board Touchscreen Installer (OpticalDrv)  "
echo "=========================================================="

echo "[1/6] Cleaning up conflicting legacy rules..."
rm -f /etc/udev/rules.d/99-irtouch.rules
rm -f /etc/X11/xorg.conf.d/99-irtouch.conf

echo "[2/6] Installing udev rules and systemd service..."
cp -v "$SCRIPT_DIR/60-eta-touchdrv.rules" /etc/udev/rules.d/60-eta-touchdrv.rules
cp -v "$SCRIPT_DIR/eta-touchdrv.service" /etc/systemd/system/eta-touchdrv.service
echo "OpticalDrv" > /etc/modules-load.d/eta-touchdrv.conf

echo "[3/6] Ensuring kernel module is present for $(uname -r)..."
mkdir -p "/lib/modules/$(uname -r)/extra"

# If precompiled module is in /lib/modules/$(uname -r)/extra, ensure it is in place
if [ -f "/lib/modules/$(uname -r)/extra/OpticalDrv.ko" ]; then
    echo "Found existing OpticalDrv.ko for $(uname -r)."
elif [ -d "/usr/src/eta-touchdrv-0.2.0" ] && command -v dkms >/dev/null 2>&1; then
    echo "Building module via DKMS..."
    dkms build -m eta-touchdrv -v 0.2.0 || true
    dkms install -m eta-touchdrv -v 0.2.0 || true
fi

echo "[4/6] Updating module dependencies..."
depmod -a

echo "[5/6] Restoring SELinux contexts (if SELinux is active)..."
if command -v restorecon >/dev/null 2>&1; then
    restorecon -v "/lib/modules/$(uname -r)/extra/"*.ko 2>/dev/null || true
    restorecon -v /etc/systemd/system/eta-touchdrv.service 2>/dev/null || true
    restorecon -v /etc/udev/rules.d/60-eta-touchdrv.rules 2>/dev/null || true
    restorecon -v /etc/modules-load.d/eta-touchdrv.conf 2>/dev/null || true
fi

echo "[6/6] Activating driver and services..."
udevadm control --reload-rules
udevadm trigger
modprobe -v OpticalDrv || true
systemctl daemon-reload
systemctl enable --now eta-touchdrv.service
systemctl restart eta-touchdrv.service || true

echo ""
echo "=== Verification ==="
if lsmod | grep -q OpticalDrv; then
    echo "✓ OpticalDrv kernel module is loaded."
else
    echo "⚠ Warning: OpticalDrv not listed in lsmod."
fi

if systemctl is-active --quiet eta-touchdrv.service; then
    echo "✓ eta-touchdrv service is active."
else
    echo "⚠ Warning: eta-touchdrv service is not active."
fi

echo ""
echo "Touchscreen installation complete!"
