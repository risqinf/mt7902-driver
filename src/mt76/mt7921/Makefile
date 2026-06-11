# SPDX-License-Identifier: ISC
#
# kbuild fragment for the mt7921-common / mt7921e modules.
# This directory is built via the parent mt76 Makefile (obj-m += mt7921/),
# so it only needs to declare the object lists.

obj-m += mt7921-common.o
obj-m += mt7921e.o

mt7921-common-y := mac.o mcu.o main.o init.o debugfs.o
mt7921e-y := pci.o pci_mac.o pci_mcu.o
