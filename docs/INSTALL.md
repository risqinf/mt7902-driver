# Installing the MT7902 driver

## Prerequisites

- A laptop with the MediaTek MT7902 (`lspci -nn | grep 14c3:7902`).
- A **supported kernel (6.16 or newer)** and its matching headers. See the
  support table in the project README. The build will stop with a clear message
  on older kernels.
- An internet connection (Ethernet or USB/phone tethering) the first time, to
  download build tools and headers.

Supported package managers: `apt`, `pacman`, `dnf`, `zypper`. Others need
manual dependency installation.

## Automatic install (recommended)

```bash
chmod +x scripts/*.sh systemd/*.sh
sudo ./scripts/install.sh
```

The script performs, in order:

1. Install build deps (`make`, `gcc`/`clang`, `bc`, `zstd`, kernel headers).
2. Back up any previous installation (modules, configs, boot loader, and
   firmware) into a timestamped directory under `/var/backups/mt7902/`.
3. Install firmware into `/lib/firmware/mediatek/`.
4. Build the Wi-Fi and Bluetooth modules against the running kernel.
5. Side-load the modules into `/lib/modules/mt7902_custom/` (stock modules are
   left untouched).
6. Install `/etc/modprobe.d/mt7902.conf`, the boot loader script, and the
   `mt7902.service` systemd unit, then enable and start it.

Re-running `install.sh` is safe. Each run first backs up the current
installation, then overwrites it with the freshly built modules and configs.
Every run keeps its own timestamped backup, so you can always roll back to a
previous state.

Reboot and verify:

```bash
ip link                     # expect a wlanX interface
nmcli dev wifi list         # expect nearby networks
bluetoothctl show           # expect a powered controller
```

### Restoring a previous installation

Backups live under `/var/backups/mt7902/<timestamp>/` and mirror the original
absolute paths. To restore one, copy the files back, for example:

```bash
sudo cp -a /var/backups/mt7902/<timestamp>/lib/modules/mt7902_custom/. \
           /lib/modules/mt7902_custom/
sudo systemctl restart mt7902.service
```

## Manual install

```bash
# 1. firmware
sudo ./scripts/install-firmware.sh

# 2. build
make -C src/mt76
make -C src/bluetooth

# 3a. side-load build output
sudo install -d /lib/modules/mt7902_custom
sudo install -m 644 src/mt76/*.ko src/mt76/mt7921/*.ko /lib/modules/mt7902_custom/
sudo install -m 644 src/bluetooth/*.ko /lib/modules/mt7902_custom/

# load now (Wi-Fi)
sudo modprobe cfg80211 mac80211
sudo insmod /lib/modules/mt7902_custom/mt76.ko
sudo insmod /lib/modules/mt7902_custom/mt76-connac-lib.ko
sudo insmod /lib/modules/mt7902_custom/mt792x-lib.ko
sudo insmod /lib/modules/mt7902_custom/mt7921-common.ko
sudo insmod /lib/modules/mt7902_custom/mt7921e.ko
```

Or, **3b.** install over the in-tree module paths and use normal `modprobe`:

```bash
sudo make -C src/mt76 install
sudo make -C src/bluetooth install
sudo modprobe mt7921e
```

## Choosing the right compiler

If your kernel was built with Clang (`grep -i clang /proc/version`), build the
modules with Clang too, otherwise module loading may fail with version magic or
relocation errors:

```bash
make -C src/mt76 CC=clang LD=ld.lld
```

`scripts/install.sh` auto-detects this.

## Uninstall

```bash
sudo ./scripts/uninstall.sh                 # keep firmware
sudo ./scripts/uninstall.sh --purge-firmware
```
