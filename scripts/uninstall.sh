#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Remove the custom MT7902 driver setup installed by scripts/install.sh.
# Firmware blobs are left in place (they are harmless and may be needed by the
# in-tree driver too); pass --purge-firmware to remove them as well.

set -uo pipefail

CUSTOM_DIR="/lib/modules/mt7902_custom"
PURGE_FW=0
[[ "${1:-}" == "--purge-firmware" ]] && PURGE_FW=1

[[ $EUID -eq 0 ]] || { echo "Run as root (sudo)." >&2; exit 1; }

echo "== Stopping and disabling service"
systemctl disable --now mt7902.service 2>/dev/null || true
rm -f /etc/systemd/system/mt7902.service
rm -f /usr/local/bin/mt7902-load.sh
systemctl daemon-reload 2>/dev/null || true

echo "== Removing modprobe blacklist"
rm -f /etc/modprobe.d/mt7902.conf

echo "== Unloading custom modules"
for m in btusb btmtk mt7921e mt7921_common mt792x_lib mt76_connac_lib mt76; do
	rmmod "$m" 2>/dev/null || true
done

echo "== Removing ${CUSTOM_DIR}"
rm -rf "${CUSTOM_DIR}"
depmod -a 2>/dev/null || true

if [[ "${PURGE_FW}" -eq 1 ]]; then
	echo "== Removing firmware blobs"
	for f in WIFI_RAM_CODE_MT7902_1.bin WIFI_MT7902_patch_mcu_1_1_hdr.bin \
	         BT_RAM_CODE_MT7902_1_1_hdr.bin; do
		rm -f "/lib/firmware/mediatek/${f}"
	done
fi

echo "== Uninstall complete. Reboot to fall back to in-tree drivers."
