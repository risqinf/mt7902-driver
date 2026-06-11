# MT7902 enablement delta (vs. upstream mt76 / mt7921)

The MT7902 is a Connac2 sibling of the MT7921. It is enabled by teaching the
existing `mt76` / `mt76-connac-lib` / `mt792x-lib` / `mt7921` modules about the
chip id `0x7902` and its handful of hardware quirks. Below is the complete set
of source changes this project carries on top of the stock kernel `mt76` tree.

## 1. Chip detection — `mt76_connac.h`

```c
static inline bool is_mt7902(struct mt76_dev *dev)
{
	return mt76_chip(dev) == 0x7902;
}

/*
 * The MT7921 hardware reports chip id 0x7961. The MT7902 is a Connac2 device
 * in the same family and shares the MT7921 code path, so both chip ids are
 * matched here.
 */
static inline bool is_mt7921(struct mt76_dev *dev)
{
	return mt76_chip(dev) == 0x7961 || is_mt7902(dev);
}

static inline bool is_connac2(struct mt76_dev *dev)
{
	return mt76_chip(dev) == 0x7961 || is_mt7922(dev) ||
	       is_mt7920(dev) || is_mt7902(dev);
}
```

`is_mt76_fw_txp()` also lists `0x7902` so the MT7902 uses the non-fw-txp path
like the rest of the MT7921 family.

## 2. Firmware names — `mt792x.h`

```c
#define MT7902_FIRMWARE_WM  "mediatek/WIFI_RAM_CODE_MT7902_1.bin"
#define MT7902_ROM_PATCH    "mediatek/WIFI_MT7902_patch_mcu_1_1_hdr.bin"
```

`mt792x_ram_name()` / `mt792x_patch_name()` return these for `case 0x7902`.

## 3. DMA ring layout — `mt7921/pci.c` (`mt7921_dma_init`)

The MT7902 differs from the MT7921 in its command/event ring assignment:

- MCU-WM TX queue lives at ring index **15** (`MT7902_TXQ_MCU_WM`).
- RX Ring0 is enlarged and shared for both RX event and TX-done
  (`MT7902_RX_MCU_RING_SIZE`, 512).
- The MT7902 does **not** use the separate MCU_WA ring (`has_mcu_wa = false`).

These are selected at runtime by reading `MT_HW_CHIPID`:

```c
bool is_mt7902 = mt7921_l1_rr(dev, MT_HW_CHIPID) == 0x7902;
if (is_mt7902) {
	layout.mcu_wm_txq           = MT7902_TXQ_MCU_WM;
	layout.mcu_rxdone_ring_size = MT7902_RX_MCU_RING_SIZE;
	layout.has_mcu_wa           = false;
}
```

## 4. Interrupt map — `mt7921/pci.c` (`mt7921_pci_probe`)

The MT7902 has no second WM RX completion source, so it needs a mutable copy of
the otherwise-`static const` irq map with `wm2_complete_mask` cleared:

```c
if (id->device == 0x7902) {
	struct mt792x_irq_map *map;

	map = devm_kmemdup(&pdev->dev, &irq_map, sizeof(irq_map), GFP_KERNEL);
	if (!map)
		return -ENOMEM;
	map->rx.wm2_complete_mask = 0;
	dev->irq_map = map;
}
```

## 5. DMA prefetch table — `mt792x_dma.c` (`mt792x_dma_prefetch`)

A dedicated `else if (is_mt7902(...))` branch programs the per-ring
`MT_WFDMA0_*_RING*_EXT_CTRL` prefetch base/depth values that match the MT7902
ring map (TX rings 0-6 + 15/16, RX rings 0-3).

## 6. PCI id + MODULE_FIRMWARE — `mt7921/pci.c`

```c
{ PCI_DEVICE(PCI_VENDOR_ID_MEDIATEK, 0x7902),
	.driver_data = (kernel_ulong_t)MT7902_FIRMWARE_WM },
...
MODULE_FIRMWARE(MT7902_FIRMWARE_WM);
MODULE_FIRMWARE(MT7902_ROM_PATCH);
```

## 7. Power-management quirk and Wi-Fi/BT coexistence note — `mt7921/init.c`

The MT7902 is excluded from the auto-enabled runtime PM path used by the PCIe
MT7921:

```c
if (!mt76_is_usb(&dev->mt76) && !is_mt7902(&dev->mt76)) {
	dev->pm.enable_user = true;
	dev->pm.enable = true;
	dev->pm.ds_enable_user = true;
	dev->pm.ds_enable = true;
}
```

This matches how mainline enables the chip and keeps the rest of the runtime PM
machinery on its default path.

On Wi-Fi/BT coexistence: the MT7902 is a single-antenna combo chip and shares
the 2.4 GHz front-end between Wi-Fi and Bluetooth. All coexistence arbitration
is handled inside the proprietary firmware; the `mt76` host driver exposes no
coexistence command, so the driver cannot improve it. Wi-Fi and Bluetooth
therefore cannot be used together reliably on 2.4 GHz. See the Known limitations
section of the README and docs/TROUBLESHOOTING.md. (Earlier revisions of this
project experimented with forcing the radio to full power and sending invented
`CHIP_CONFIG` coex strings; the firmware ignored the strings and the forced
full-power state hurt stability, so those changes were reverted.)

## 8. Bluetooth — `bluetooth/btmtk.{c,h}` and `bluetooth/btusb.c`

```c
/* btmtk.h */
#define FIRMWARE_MT7902 "mediatek/BT_RAM_CODE_MT7902_1_1_hdr.bin"

/* btmtk.c — firmware filename selection */
case 0x7902:
	btmtk_fw_get_filename(...);

/* btusb.c — MT7902 USB-transport BT device ids */
{ USB_DEVICE(0x0e8d, 0x1ede), .driver_info = BTUSB_MEDIATEK | BTUSB_WIDEBAND_SPEECH },
{ USB_DEVICE(0x13d3, 0x3579), ... },
{ USB_DEVICE(0x13d3, 0x3580), ... },
{ USB_DEVICE(0x13d3, 0x3594), ... },
{ USB_DEVICE(0x13d3, 0x3596), ... },
```

## 9. Kernel 6.19 build compatibility fixes

The driver source is a snapshot from the Linux 7.0 development cycle. A few
newer kernel APIs it used do not exist in 6.16 - 6.19, so they were replaced
with equivalents available across the supported range:

- `agg-rx.c`: `kzalloc_flex(*tid, reorder_buf, size)` replaced with
  `kzalloc(struct_size(tid, reorder_buf, size), GFP_KERNEL)`.
- `bluetooth/btusb.c`, `bluetooth/btmtk.c`: `kmalloc_obj()` / `kzalloc_obj()`
  replaced with `kmalloc(sizeof(*p), GFP_KERNEL)` / `kzalloc(...)`.
- `bluetooth/btusb.c`: `hci_discovery_active()` (added in 7.0) dropped from the
  auto-suspend guard, matching the 6.19 logic that only checks
  `hci_conn_count()`.
- `bluetooth/`: the kernel-internal `btintel.h`, `btbcm.h`, and `btrtl.h`
  headers are vendored as `CONFIG`-gated copies. Because `CONFIG_BT_INTEL`,
  `CONFIG_BT_BCM`, and `CONFIG_BT_RTL` are not set for this out-of-tree build,
  their no-op static-inline fallbacks satisfy the references in `btusb.c`
  without pulling in the Intel/Broadcom/Realtek vendor modules.

## Notes on the rewrite

The upstream-tracking source this project is based on carried a large amount of
`printk(KERN_DEBUG ...)` / `dev_info(...)` tracing in hot paths. This rewrite
removes that debug instrumentation and keeps the functional MT7902 changes
listed above, so the modules build cleanly and run quietly.

Mainline Linux gained official MT7902 support in the 7.0/7.1 series; once your
distribution ships that kernel you can drop this out-of-tree driver entirely.
