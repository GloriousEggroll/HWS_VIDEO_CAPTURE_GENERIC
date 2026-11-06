# Changelog

User-visible changes. [docs/MERGE.md](docs/MERGE.md) explains the merge. The two drivers' earlier changes are in [docs/vc12-4k/CHANGELOG.md](docs/vc12-4k/CHANGELOG.md) and [docs/vc41-vc42/CHANGELOG.md](docs/vc41-vc42/CHANGELOG.md).

## 1.3.0

ACASIS's drivers are merged. [docs/MERGE.md](docs/MERGE.md#acasis) lists what each one contributed.

- New cards: ACASIS's AHD cards (`8888:5504`, 4 inputs; `8888:5502`, 2 inputs), named AVideo, with no sound card; and `8888:8521`, 1 input, on the HD path.
- `1F33:6502` now has 2 inputs, as in ACASIS's newer driver. AVMatrix's gave it 4.
- 640×480 is a new output size on the HD family, except AHD cards.
- Each release has DKMS packages for Fedora 45 and 44, Debian 13 and 12, and Ubuntu 26.10 and 26.04.
- New optional `tools/wireplumber-names.sh`, from ACASIS's rules: OBS and other PipeWire programs show each input's sound card by name.
- `install.sh` and `uninstall.sh` also remove `HwsAHDCapture` and what ACASIS's Kylin installer left: a boot service and `/opt/HWS/ko`.
- If a card has no sound, its audio work items are still set up, so unloading the driver doesn't crash.

## 1.2.0

The VC12-4K driver (`HwsUHDX1Capture` 1.1.0, at `7a03be9`) and the VC41/VC42 driver (`HwsCapture` 1.1.0, at `95231a4`) are now one module, `hwsvideo`.

### Changed for everyone

- The module is `hwsvideo` and the DKMS package `hwsvideo`. `install.sh` removes both old drivers. Options in `/etc/modprobe.d/hws.conf` need the new module name.
- The in-kernel `hws` driver's blacklist moves to `/etc/modprobe.d/hwsvideo.conf`, and is now written on VC12-4K systems too, where it has no effect on the card.
- `/sys/kernel/debug/hws-<pci address>/status` has one block per channel on every card, and the `dma` file names the card's family.
- `tests/` works with either kind of card.

### Changed for the VC41, VC42 and relatives

- The status thread takes `engine_lock` before it may restart a channel's capture on an input-size change, as the VC12-4K driver does. Without it, the restart could race with a program stopping its capture.
- A DMA buffer that crosses a 512 MiB boundary, which the card's address windows can't reach, now fails the driver's load instead of being used.
- These cards now use the VC12-4K's copy of the scalers. They are the same functions, plus branches for 4K inputs these cards never see.

### Unchanged

Device names, PCI IDs, input limits, output sizes, controls, colorimetry, the capture paths and zero-copy stay as each driver had them.
