# Sources and prior work

This project did not start from scratch. It consolidates and reorganizes the
existing community effort to run the MediaTek MT7902 on Linux, on top of the
mainline `mt76` driver. This page credits those sources.

## Upstream driver

- Linux kernel `mt76` driver (Wi-Fi)
  https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
  Path: `drivers/net/wireless/mediatek/mt76`
- Linux kernel Bluetooth subsystem (`btusb`, `btmtk`)
  Path: `drivers/bluetooth`

The MT7902 is enabled as a member of the MT7921 / MT792x / Connac2 family.
Mainline Linux gained MT7902 support during the 7.0/7.1 development cycle.

## Community repositories referenced

- OnlineLearningTutorials/mt7902_temp
  https://github.com/OnlineLearningTutorials/mt7902_temp
  The base approach of enabling MT7902 through the MT7921 code path, plus the
  per-kernel-version driver trees and firmware blobs.

- samveen/mt7902-dkms
  https://github.com/samveen/mt7902-dkms
  DKMS packaging approach: cloning the in-kernel MT7921 driver and adapting it
  for MT7902, with firmware retrieval notes.

- keepsoftware/mt7902-dkms
  https://github.com/keepsoftware/mt7902-dkms
  Related DKMS packaging effort.

- hmtheboy154/gen4-mt7902
  https://github.com/hmtheboy154/gen4-mt7902
  An earlier MT7902 driver (working with limitations) used as a reference.

- DarkMatter-999/mt7902driver
  https://github.com/DarkMatter-999/mt7902driver
  A stop-gap NDISWrapper-based approach using the Windows driver.

## Discussion threads and write-ups

- MediaTek MT7902 WiFi not working on Ubuntu 24.04 (Ask Ubuntu)
  https://askubuntu.com/questions/1536725/mediatek-mt7902-wifi-not-working-on-ubuntu-24-04
- MT7902 driver for Ubuntu (Unix & Linux Stack Exchange)
  https://unix.stackexchange.com/questions/763127/mt7902-driver-for-ubuntu
- Backport request for MT7902 (Fedora discussion)
  https://discussion.fedoraproject.org/t/backport-request-for-mt7902-mediatek-mt76-mt792x-fix-to-fedora-kernel/192463

## Hardware references

- MediaTek MT7902 Reference Design (PCI id 14c3:7902)
- linux-hardware.org device database entry for `pci:14c3-7902`

## MT7902 enablement delta

For the precise set of source changes that enable the MT7902 on top of the
upstream `mt76`/`mt7921` driver, see
[../patches/mt7902-enablement.md](../patches/mt7902-enablement.md).
