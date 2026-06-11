# SPDX-License-Identifier: ISC
#
# Out-of-tree build for the MT7902 Wi-Fi driver (mt76 / mt792x / mt7921 family).
#
# Targets:
#   make                -> build the kernel modules (default)
#   make modules        -> same as above
#   make module_compress-> zstd-compress the built .ko files
#   make module_install -> install compressed modules into the running kernel
#   make install        -> build + compress + install in one step
#   make clean          -> remove build artifacts
#
# The default target ONLY builds. Installation is kept as an explicit step so a
# failed build can never leave the system with half-installed modules.

obj-m += mt76.o
obj-m += mt76-connac-lib.o
obj-m += mt792x-lib.o
obj-m += mt7921/

KVER     ?= $(shell uname -r)
KDIR     ?= /lib/modules/$(KVER)/build
MOD_DIR   = /lib/modules/$(KVER)/kernel/drivers/net/wireless/mediatek/mt76
ZSTD_BINS = mt76.ko.zst mt76-connac-lib.ko.zst mt792x-lib.ko.zst

CFLAGS_trace.o := -I$(src)
CFLAGS_mt792x_trace.o := -I$(src)

mt76-y := \
	mmio.o util.o trace.o dma.o mac80211.o debugfs.o eeprom.o \
	tx.o agg-rx.o mcu.o wed.o scan.o channel.o pci.o

mt76-connac-lib-y := mt76_connac_mcu.o mt76_connac_mac.o mt76_connac3_mac.o

mt792x-lib-y := mt792x_core.o mt792x_mac.o mt792x_trace.o \
		mt792x_debugfs.o mt792x_dma.o mt792x_acpi_sar.o

.PHONY: all modules module_compress module_install install clean

all: modules

modules:
	@echo "== Building MT7902 Wi-Fi modules for kernel $(KVER)"
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules

module_compress: modules
	@echo "== Compressing modules (zstd)"
	@find . -name "*.ko" -exec zstd -f -q {} \;

module_install: module_compress
	@echo "== Installing modules into $(MOD_DIR)"
	install -d $(MOD_DIR) $(MOD_DIR)/mt7921
	install -v -m 644 $(ZSTD_BINS) $(MOD_DIR)
	install -v -m 644 mt7921/*.ko.zst $(MOD_DIR)/mt7921/
	depmod -a $(KVER)

install: module_install

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean
	rm -f $(ZSTD_BINS) mt7921/*.ko.zst
