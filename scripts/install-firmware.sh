#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Install the MT7902 Wi-Fi + Bluetooth firmware blobs into /lib/firmware/mediatek.
# Existing files are backed up (.bak) before being overwritten.

set -euo pipefail

FW_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../firmware" && pwd)"
FW_DST="/lib/firmware/mediatek"

if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root (use sudo)." >&2
	exit 1
fi

FILES=(
	"WIFI_RAM_CODE_MT7902_1.bin"
	"WIFI_MT7902_patch_mcu_1_1_hdr.bin"
	"BT_RAM_CODE_MT7902_1_1_hdr.bin"
)

echo "== Installing MT7902 firmware into ${FW_DST}"
install -d "${FW_DST}"

for f in "${FILES[@]}"; do
	src="${FW_SRC}/${f}"
	dst="${FW_DST}/${f}"
	if [[ ! -f "${src}" ]]; then
		echo "  ! missing source firmware: ${src}" >&2
		continue
	fi
	if [[ -f "${dst}" ]]; then
		cp -a "${dst}" "${dst}.bak"
		echo "  backed up existing ${f} -> ${f}.bak"
	fi
	install -m 644 "${src}" "${dst}"
	echo "  installed ${f}"
done

# Some distros ship a compressed BT blob that conflicts with the one above.
if [[ -f "${FW_DST}/mt7902/BT_RAM_CODE_MT7902_1_1_hdr.bin.zst" ]]; then
	echo "  ! note: ${FW_DST}/mt7902/BT_RAM_CODE_MT7902_1_1_hdr.bin.zst exists and may"
	echo "    conflict with the flat blob. Remove it if Bluetooth fails to load."
fi

echo "== Refreshing initramfs (best effort)"
if command -v update-initramfs >/dev/null 2>&1; then
	update-initramfs -u || true
elif command -v dracut >/dev/null 2>&1; then
	dracut -f || true
fi

echo "== Firmware installation complete."
