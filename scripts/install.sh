#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# MT7902 Wi-Fi + Bluetooth driver installer.
#
# This script:
#   1. Installs build dependencies for the detected package manager.
#   2. Backs up any previous installation into a timestamped directory.
#   3. Installs the MT7902 firmware blobs.
#   4. Builds the Wi-Fi and Bluetooth modules against the running kernel.
#   5. Side-loads the modules into /lib/modules/mt7902_custom (does not
#      overwrite stock kernel modules).
#   6. Installs a systemd service so the modules load on every boot.
#
# Re-running the script is safe: it always backs up the previous installation
# first, then overwrites it with the freshly built modules and configs. Each
# run keeps its own timestamped backup under /var/backups/mt7902/.
#
# Usage:
#   sudo ./scripts/install.sh
#
# A working internet connection (Ethernet or USB tethering) is required the
# first time so the kernel headers / build tools can be downloaded.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WIFI_SRC="${PROJECT_DIR}/src/mt76"
BT_SRC="${PROJECT_DIR}/src/bluetooth"
CUSTOM_DIR="/lib/modules/mt7902_custom"
KVER="$(uname -r)"

# Timestamped backup directory for this run.
BACKUP_ROOT="/var/backups/mt7902"
BACKUP_DIR="${BACKUP_ROOT}/$(date +%Y%m%d-%H%M%S)"

log()  { echo -e "\033[1;32m==\033[0m $*"; }
warn() { echo -e "\033[1;33m!!\033[0m $*" >&2; }
die()  { echo -e "\033[1;31mXX\033[0m $*" >&2; exit 1; }

# Copy an existing file or directory into the timestamped backup, preserving
# its absolute path layout. No-op if the source does not exist.
BACKED_UP_ANY=0
backup_path() {
	local src="$1"
	[[ -e "${src}" ]] || return 0
	local dst="${BACKUP_DIR}${src}"
	install -d "$(dirname "${dst}")"
	cp -a "${src}" "${dst}"
	BACKED_UP_ANY=1
	log "  backed up ${src}"
}

[[ $EUID -eq 0 ]] || die "This script must be run as root (use sudo)."

# ---------------------------------------------------------------------------
# 0. Kernel version sanity check
# ---------------------------------------------------------------------------
# This driver snapshot needs Linux 6.16 or newer (see README.md). Fail early
# with a clear message rather than after installing build dependencies.
KMAJOR="${KVER%%.*}"
KREST="${KVER#*.}"
KMINOR="${KREST%%.*}"
if (( KMAJOR < 6 || (KMAJOR == 6 && KMINOR < 12) )); then
    die "Kernel ${KVER} is too old. This driver requires Linux 6.12 or newer."
fi
log "Kernel ${KVER} is within the supported range (6.12+)."

# ---------------------------------------------------------------------------
# 0b. Secure Boot advisory
# ---------------------------------------------------------------------------
# On Secure Boot systems (common on Fedora), the kernel refuses to load
# unsigned out-of-tree modules. Warn early; this is the most frequent reason a
# successful build still fails to load.
if command -v mokutil >/dev/null 2>&1; then
	if mokutil --sb-state 2>/dev/null | grep -qi "enabled"; then
		warn "Secure Boot is ENABLED."
		warn "Unsigned modules will be rejected at load time (Required key not available)."
		warn "Either disable Secure Boot in your firmware, or sign the modules with a MOK."
		warn "See docs/INSTALL.md section 'Secure Boot' for the signing procedure."
		warn "Continuing with build and install; loading may fail until this is resolved."
	fi
fi

# ---------------------------------------------------------------------------
# 1. Build dependencies
# ---------------------------------------------------------------------------
log "Installing build dependencies for kernel ${KVER}"
if command -v apt-get >/dev/null 2>&1; then
	apt-get update
	apt-get install -y build-essential "linux-headers-${KVER}" bc zstd \
		clang llvm lld || warn "apt dependency install reported errors"
elif command -v pacman >/dev/null 2>&1; then
	pacman -Sy --needed --noconfirm base-devel linux-headers bc zstd \
		clang llvm lld || warn "pacman dependency install reported errors"
elif command -v dnf >/dev/null 2>&1; then
	dnf install -y "kernel-devel-${KVER}" kernel-headers gcc make bc zstd \
		clang llvm lld || warn "dnf dependency install reported errors"
	# Fallback if the exact versioned kernel-devel is not in the repos yet.
	if [[ ! -d "/lib/modules/${KVER}/build" ]]; then
		warn "kernel-devel-${KVER} not found; trying generic kernel-devel"
		dnf install -y kernel-devel || true
	fi
elif command -v zypper >/dev/null 2>&1; then
	zypper install -y -t pattern devel_basis || true
	zypper install -y kernel-default-devel bc zstd clang llvm lld \
		|| warn "zypper dependency install reported errors"
else
	warn "No supported package manager found."
	warn "Install manually: make, gcc/clang, bc, zstd and kernel headers for ${KVER}."
fi

[[ -d "/lib/modules/${KVER}/build" ]] || \
	die "Kernel headers for ${KVER} not found at /lib/modules/${KVER}/build"

# Match the compiler the kernel was built with to avoid module load failures.
# Use a regular array and guard its expansion so an empty array is safe under
# `set -u` on older bash releases.
COMPILER_ARGS=()
if grep -qi "clang" /proc/version; then
	log "Clang-built kernel detected; building modules with clang"
	COMPILER_ARGS=(CC=clang LD=ld.lld)
else
	log "GCC-built kernel detected; building modules with gcc"
fi

# Helper to run make with the optional compiler args safely.
run_make() {
	local dir="$1"; shift
	if [[ ${#COMPILER_ARGS[@]} -gt 0 ]]; then
		make -C "${dir}" "${COMPILER_ARGS[@]}" "$@"
	else
		make -C "${dir}" "$@"
	fi
}

# ---------------------------------------------------------------------------
# 2. Back up any previous installation before overwriting
# ---------------------------------------------------------------------------
# Every run preserves the currently-installed modules, configs, boot loader and
# firmware into a fresh timestamped directory. Re-running therefore overwrites
# the live installation while always keeping the previous one recoverable.
log "Backing up any previous installation into ${BACKUP_DIR}"
backup_path "${CUSTOM_DIR}"
backup_path /etc/modprobe.d/mt7902.conf
backup_path /usr/local/bin/mt7902-load.sh
backup_path /etc/systemd/system/mt7902.service
for f in WIFI_RAM_CODE_MT7902_1.bin WIFI_MT7902_patch_mcu_1_1_hdr.bin \
         BT_RAM_CODE_MT7902_1_1_hdr.bin; do
	backup_path "/lib/firmware/mediatek/${f}"
done
if [[ "${BACKED_UP_ANY}" -eq 1 ]]; then
	log "Previous installation backed up to ${BACKUP_DIR}"
else
	rmdir "${BACKUP_DIR}" 2>/dev/null || true
	log "No previous installation found; nothing to back up."
fi

# ---------------------------------------------------------------------------
# 3. Firmware
# ---------------------------------------------------------------------------
log "Installing firmware"
"${PROJECT_DIR}/scripts/install-firmware.sh"

# ---------------------------------------------------------------------------
# 4. Build modules
# ---------------------------------------------------------------------------
log "Building Wi-Fi modules"
make -C "${WIFI_SRC}" clean >/dev/null 2>&1 || true
run_make "${WIFI_SRC}" modules

if [[ -d "${BT_SRC}" ]]; then
	log "Building Bluetooth modules"
	make -C "${BT_SRC}" clean >/dev/null 2>&1 || true
	run_make "${BT_SRC}" modules || \
		warn "Bluetooth build failed; continuing with Wi-Fi only"
fi

# ---------------------------------------------------------------------------
# 5. Side-load install
# ---------------------------------------------------------------------------
log "Installing modules into ${CUSTOM_DIR}"
install -d "${CUSTOM_DIR}"
install -v -m 644 "${WIFI_SRC}"/*.ko "${CUSTOM_DIR}/"
install -v -m 644 "${WIFI_SRC}"/mt7921/*.ko "${CUSTOM_DIR}/"
if [[ -f "${BT_SRC}/btmtk.ko" ]]; then
	install -v -m 644 "${BT_SRC}/btmtk.ko" "${BT_SRC}/btusb.ko" "${CUSTOM_DIR}/"
fi

# ---------------------------------------------------------------------------
# 6. modprobe blacklist + systemd service
# ---------------------------------------------------------------------------
log "Installing modprobe blacklist"
install -m 644 "${PROJECT_DIR}/modprobe.d/mt7902.conf" /etc/modprobe.d/mt7902.conf

log "Installing boot-time loader and systemd service"
install -m 755 "${PROJECT_DIR}/systemd/mt7902-load.sh" /usr/local/bin/mt7902-load.sh
install -m 644 "${PROJECT_DIR}/systemd/mt7902.service" /etc/systemd/system/mt7902.service

systemctl daemon-reload
systemctl enable mt7902.service
systemctl restart mt7902.service || warn "Service start reported errors; check 'journalctl -u mt7902'"

log "Installation complete."
if [[ "${BACKED_UP_ANY}" -eq 1 ]]; then
	log "Previous installation preserved at:  ${BACKUP_DIR}"
fi
log "Verify Wi-Fi with:  ip link        and  nmcli dev wifi list"
log "Verify Bluetooth with:  bluetoothctl show"
log "If something is wrong, inspect:  dmesg | grep -i -E 'mt76|mt7921|mt7902'"
