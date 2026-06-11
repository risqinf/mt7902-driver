# SPDX-License-Identifier: GPL-2.0
#
# Out-of-tree build for the MT7902 Bluetooth modules (btusb + btmtk).
#
# Targets:
#   make                -> build btusb.ko and btmtk.ko (default)
#   make module_compress-> zstd-compress the built .ko files
#   make module_install -> install compressed modules into the running kernel
#   make install        -> build + compress + install
#   make clean          -> remove build artifacts

obj-m += btusb.o
obj-m += btmtk.o

KVER     ?= $(shell uname -r)
KDIR     ?= /lib/modules/$(KVER)/build
MOD_DIR   = /lib/modules/$(KVER)/kernel/drivers/bluetooth
ZSTD_BINS = btusb.ko.zst btmtk.ko.zst

.PHONY: all modules module_compress module_install install clean

all: modules

modules:
	@echo "== Building MT7902 Bluetooth modules for kernel $(KVER)"
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules

module_compress: modules
	@echo "== Compressing modules (zstd)"
	@find . -name "*.ko" -exec zstd -f -q {} \;

module_install: module_compress
	@echo "== Installing modules into $(MOD_DIR)"
	install -d $(MOD_DIR)
	install -v -m 644 $(ZSTD_BINS) $(MOD_DIR)
	depmod -a $(KVER)

install: module_install

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean
	rm -f $(ZSTD_BINS)
