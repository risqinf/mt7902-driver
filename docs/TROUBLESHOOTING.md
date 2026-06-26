# MT7902 troubleshooting

Start by collecting state:

```bash
lspci -nn | grep -i 14c3            # confirm the device id (14c3:7902)
dmesg | grep -i -E 'mt76|mt7921|mt7902|firmware'
rfkill list
ip link
journalctl -u mt7902 --no-pager
```

## Driver loads but no networks are detected

Symptoms: `mt7921e` binds, `ip link` shows an interface, but
`nmcli dev wifi list` is empty.

Things to check, in order:

1. **Chip-detection helper.** Confirm `src/mt76/mt76_connac.h` defines
   `is_mt7921()` to match both the MT7921 (`0x7961`) and the MT7902 (`0x7902`):
   ```c
   static inline bool is_mt7921(struct mt76_dev *dev)
   {
       return mt76_chip(dev) == 0x7961 || is_mt7902(dev);
   }
   ```
   The MT7902 shares the MT7921 code path, so this helper must return true for
   it; otherwise the shared paths used during scanning behave incorrectly. This
   package ships the correct definition.

2. **Firmware present and uncompressed-conflict free.**
   ```bash
   ls -l /lib/firmware/mediatek/WIFI_RAM_CODE_MT7902_1.bin \
         /lib/firmware/mediatek/WIFI_MT7902_patch_mcu_1_1_hdr.bin
   ```
   `dmesg` should show the firmware loading and `MCU` capability messages, not
   `Direct firmware load ... failed`.

3. **rfkill.**
   ```bash
   sudo rfkill unblock all
   ```

4. **Regulatory domain.** A missing/`00` country can disable channels:
   ```bash
   iw reg get
   sudo iw reg set US        # use your actual country code
   ```

## "read kernel buffer failed: Operation not permitted"

This is a `dmesg` permission message, not a driver error:

```bash
sudo dmesg | grep -i mt76
# or relax the restriction for the session:
sudo sysctl kernel.dmesg_restrict=0
```

## Wi-Fi unstable when Bluetooth is on (cannot use both at once)

Symptoms: Wi-Fi works fine on its own. The moment Bluetooth is switched on -
even before pairing or connecting to any device - the Wi-Fi link becomes
unstable, throughput collapses, or it disconnects and will not reconnect to a
2.4 GHz network. Turning Bluetooth off restores Wi-Fi. In effect you can use
Wi-Fi or Bluetooth, but not both at the same time.

Root cause: this is a hardware limitation, not a bug in this package. The
MT7902 is a single-antenna combo chip. Wi-Fi and Bluetooth share one antenna
and the same 2.4 GHz RF front-end, and all coexistence arbitration is done
inside the proprietary firmware. On this chip the arbiter cannot keep a 2.4 GHz
Wi-Fi link healthy once the Bluetooth radio is active. The open `mt76` driver
has no coexistence command to influence this, so there is no software fix.

The only effective workaround - run Wi-Fi on 5 GHz:

Putting Wi-Fi on the 5 GHz band moves it off the 2.4 GHz spectrum that
Bluetooth uses, so the two radios stop colliding. This requires a dual-band
router.

```bash
# Check which bands your APs offer (channels 36-165 are 5 GHz; 1-13 are 2.4 GHz)
nmcli -f SSID,CHAN,FREQ dev wifi list

# Connect to the 5 GHz SSID, or lock a connection to the 5 GHz band
nmcli connection modify "<your-wifi-name>" 802-11-wireless.band a
nmcli connection up "<your-wifi-name>"
```

If your router broadcasts a single name for both bands, give the 5 GHz band its
own SSID in the router settings so you can select it explicitly.

If only 2.4 GHz networks are available, the limitation cannot be removed. You
can only reduce its impact:

- Use either Wi-Fi or Bluetooth at a time (turn Bluetooth off while you need
  reliable Wi-Fi).
- Stay close to the router for the strongest possible 2.4 GHz signal.
- Use a wired or USB-tethered connection while Bluetooth audio is in use.

## Bluetooth not working

```bash
dmesg | grep -i -E 'btusb|btmtk|bluetooth'
```

- If you see a firmware conflict, a distro-shipped compressed blob may clash:
  ```bash
  sudo rm /lib/firmware/mediatek/mt7902/BT_RAM_CODE_MT7902_1_1_hdr.bin.zst
  ```
  This package installs the flat `BT_RAM_CODE_MT7902_1_1_hdr.bin` blob.
- Reload the BT modules:
  ```bash
  sudo rmmod btusb btmtk
  sudo insmod /lib/modules/mt7902_custom/btmtk.ko
  sudo insmod /lib/modules/mt7902_custom/btusb.ko
  sudo systemctl restart bluetooth
  ```

## Build stops with "targets Linux 6.12 or newer"

Your running kernel is older than this driver snapshot supports. The mt76 code
here depends on APIs that do not exist on kernels older than 6.12.

Options:
- Boot a 6.12+ kernel and rebuild.
- On a distribution shipping Linux 7.1+, drop this package and use the in-tree
  MT7902 support instead.

## Build fails with pp_page_to_nmdesc or page_pool errors

Symptom: `error: implicit declaration of function 'pp_page_to_nmdesc'`

This means the `page_pool` API compatibility shim is not being applied. The
driver uses a version-guarded `#if` in `mt76.h` to handle the API difference:

- **Kernel 6.12–6.15**: uses `page->pp` (direct `struct page` member)
- **Kernel 6.16+/7.0+**: uses `pp_page_to_nmdesc(page)->pp` (netmem API)

If you see this error, verify that `linux/version.h` is present in your kernel
headers and that `LINUX_VERSION_CODE` is correctly defined. Rebuild:

```bash
sudo make -C src/mt76 clean && sudo ./scripts/install.sh
```

## Module fails to load (version magic / unknown symbol)

The module was built against a different kernel or compiler than the running
one. Rebuild:

```bash
sudo make -C src/mt76 clean && sudo ./scripts/install.sh
```

If the kernel is Clang-built, pass `CC=clang LD=ld.lld` (install.sh detects
this automatically).

## After a kernel upgrade

Side-loaded modules in `/lib/modules/mt7902_custom` are not tied to a specific
kernel directory, but they were compiled for the old kernel ABI. Re-run the
installer after every kernel upgrade:

```bash
sudo ./scripts/install.sh
```

For a hands-off setup consider packaging via DKMS (see samveen/mt7902-dkms for
a reference `dkms.conf`).

## Falling back to mainline

Mainline Linux 7.0/7.1 includes MT7902 support. Once your distribution ships
such a kernel, uninstall this package and use the in-tree driver:

```bash
sudo ./scripts/uninstall.sh
```
