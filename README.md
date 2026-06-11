# MT7902 Linux Driver (Wi-Fi 6E + Bluetooth)

An out-of-tree driver package for the **MediaTek MT7902** (PCI id `14c3:7902`),
the Wi-Fi 6E + Bluetooth combo chip shipped in many ASUS Vivobook and other
laptops.

The MT7902 belongs to the same Connac2 family as the MT7921, so this package
enables it by extending the in-kernel `mt76` / `mt7921` driver with the MT7902
chip id and its hardware quirks, rather than writing a new driver from scratch.
This is the same approach that landed in mainline Linux during the 7.0/7.1
cycle. See [docs/SOURCES.md](docs/SOURCES.md) for full attribution to the prior
community work this builds on, and
[patches/mt7902-enablement.md](patches/mt7902-enablement.md) for the exact
source delta versus upstream `mt76`.

## Supported kernels

The driver source is a snapshot of mainline `mt76` from the Linux 7.0 cycle and
depends on recent kernel interfaces.

| Kernel            | Status                                            |
|-------------------|---------------------------------------------------|
| 7.0.x             | Supported (this is the upstream snapshot target)  |
| 6.19.x            | Supported and tested (6.19.10)                    |
| 6.16 - 6.18       | Supported                                         |
| 6.12 - 6.15       | Not supported by this snapshot; may need API edits|
| 5.19 and older    | Not supported - required APIs do not exist        |

A build-time guard in `src/mt76/mt76_compat.h` stops the build with a clear
message on kernels below 6.16 instead of emitting a wall of errors.

### Tested configuration

This package was built and verified on:

- Laptop: ASUS Vivobook Go 14 / 15
- Distribution: Fedora 44
- Kernel: 6.19.10-300.fc44.x86_64
- Compiler: GCC (GCC-built kernel)
- Result: Wi-Fi and Bluetooth both working, including simultaneous use

> Note on distributions: a modern Fedora release (Fedora 41/42 and later) ships
> a 6.1x/7.x kernel, which is the right target. Kernel 5.19 is too old for this
> driver: there is no MT7902-capable `mt76` code for that series. If your
> distribution already ships Linux 7.1+, it includes MT7902 support natively and
> you do not need this package.

## Project layout

```
mt7902-driver/
├── README.md
├── LICENSE                   # MIT (project's own files)
├── NOTICE                    # licensing of vendored sources + firmware
├── src/
│   ├── mt76/                 # Wi-Fi driver (mt76 core + connac-lib + mt792x-lib + mt7921)
│   │   ├── Makefile          # out-of-tree build (build-only by default)
│   │   ├── mt76_compat.h     # build-time kernel-version guard
│   │   └── mt7921/           # mt7921-common + mt7921e (MT7902 rides this path)
│   └── bluetooth/            # btusb.ko + btmtk.ko + Makefile
├── firmware/                 # MT7902 Wi-Fi + BT firmware blobs (proprietary)
├── scripts/
│   ├── install.sh            # deps + firmware + build + side-load + service
│   ├── install-firmware.sh   # copy firmware into /lib/firmware/mediatek
│   └── uninstall.sh          # remove everything this package installed
├── systemd/
│   ├── mt7902.service        # loads the custom modules at boot
│   └── mt7902-load.sh        # loader invoked by the service
├── modprobe.d/
│   └── mt7902.conf           # blacklist stock mt7921e/mt7925e auto-binding
├── patches/
│   └── mt7902-enablement.md  # exact source delta vs. upstream mt76
└── docs/
    ├── INSTALL.md
    ├── TROUBLESHOOTING.md
    └── SOURCES.md
```

## Quick start

```bash
chmod +x scripts/*.sh systemd/*.sh
sudo ./scripts/install.sh
```

This installs build dependencies, copies firmware, builds the Wi-Fi and
Bluetooth modules against your running kernel, side-loads them into
`/lib/modules/mt7902_custom`, and enables a systemd service that loads them on
every boot. See [docs/INSTALL.md](docs/INSTALL.md) for manual steps and
[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for diagnostics.

## Build only (no install)

```bash
make -C src/mt76                 # Wi-Fi modules
make -C src/bluetooth            # Bluetooth modules
```

To install over the in-tree module paths instead of side-loading:

```bash
sudo make -C src/mt76 install
sudo make -C src/bluetooth install
```

## Status and expectations

This is a cleaned-up, restructured consolidation of the community MT7902 work.
It builds the Wi-Fi and Bluetooth modules, installs firmware, and wires up boot
loading. It has been verified working on the tested configuration above: Wi-Fi
and Bluetooth each work correctly. Note that they cannot be used at the same
time on 2.4 GHz; see Known limitations below. Results on other boards or kernels
may vary; test reports and contributions are welcome.

## Known limitations

Wi-Fi and Bluetooth cannot be used reliably at the same time on the 2.4 GHz
band.

The MT7902 is a single-antenna combo chip: Wi-Fi and Bluetooth share one
antenna and the same 2.4 GHz RF front-end. Coexistence is arbitrated entirely
inside the proprietary firmware, and on this chip the arbiter is weak. As soon
as the Bluetooth radio is powered on (even when not connected to any device),
a 2.4 GHz Wi-Fi link becomes unstable or drops, and will not reconnect until
Bluetooth is turned off. Wi-Fi on its own, and Bluetooth on its own, are both
stable.

This is a hardware/firmware limitation. The open `mt76` driver has no
coexistence command to change it, so it cannot be fixed in this package. The
only effective workaround is to run Wi-Fi on the 5 GHz band (a different
frequency from 2.4 GHz Bluetooth), which requires a dual-band router. If only
2.4 GHz networks are available, use either Wi-Fi or Bluetooth at a time. See
[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for details and partial
mitigations.

## Licensing

- The project's own files (build wrappers, scripts, systemd units, modprobe
  config, documentation) are licensed under the **MIT License** — see
  [LICENSE](LICENSE).
- The vendored driver sources under `src/` keep their original kernel licenses
  (mostly **BSD-3-Clause-Clear** for Wi-Fi, **GPL-2.0** / **ISC** for
  Bluetooth), as declared by the SPDX tag in each file.
- The firmware blobs under `firmware/` are **proprietary** MediaTek images.

See [NOTICE](NOTICE) for the full breakdown.

## Support

If this driver helped you get the MT7902 working, you can support the work here:

- Ko-fi: https://ko-fi.com/risqinf
