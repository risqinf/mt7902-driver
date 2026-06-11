#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Boot-time loader for the custom MT7902 modules.
# Installed to /usr/local/bin/mt7902-load.sh by scripts/install.sh and invoked
# by the mt7902.service systemd unit.

set -u

CUSTOM_DIR="/lib/modules/mt7902_custom"

log() { echo "mt7902-load: $*"; }

# Drop any stock modules that may have grabbed the device first.
for m in btusb btmtk mt7921e mt7925e mt7925_common mt7921_common \
         mt792x_lib mt76_connac_lib mt76; do
	rmmod "$m" 2>/dev/null || true
done

# Bring up the mac80211 stack dependencies.
modprobe cfg80211 || true
modprobe mac80211 || true

# Load the Wi-Fi stack in dependency order.
for ko in mt76 mt76-connac-lib mt792x-lib mt7921-common mt7921e; do
	if [[ -f "${CUSTOM_DIR}/${ko}.ko" ]]; then
		insmod "${CUSTOM_DIR}/${ko}.ko" 2>/dev/null \
			&& log "loaded ${ko}" \
			|| log "WARN: failed to load ${ko}"
	fi
done

# Load the Bluetooth stack if the custom BT modules are present.
if [[ -f "${CUSTOM_DIR}/btmtk.ko" ]]; then
	modprobe bluetooth || true
	modprobe btrtl || true
	modprobe btintel || true
	modprobe btbcm || true

	insmod "${CUSTOM_DIR}/btmtk.ko" 2>/dev/null && log "loaded btmtk" || true
	insmod "${CUSTOM_DIR}/btusb.ko" 2>/dev/null && log "loaded btusb" || true

	systemctl restart bluetooth 2>/dev/null || true
fi

log "done"
