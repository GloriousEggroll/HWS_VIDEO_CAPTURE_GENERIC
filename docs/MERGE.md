# How the two drivers were combined

`hwsvideo` combines the VC12-4K driver (`AVMATRIX-VC12-4K-CAPTURE` at `7a03be9`) and the VC41/VC42 driver (`AVMATRIX-VC41-VC42-CAPTURE` at `95231a4`). Before the merge, 102 of their functions were identical (ignoring whitespace), mainly the V4L2 ioctls, the ALSA code, the DMA engine control and the teardown.

The cards do differ in how frames reach memory, so the driver keeps both capture paths and picks one per card at probe time. Each row of `hws_pci_table` points at a `struct hws_card_info` (`hws_card_uhd` or `hws_card_hd`), and code that differs tests `hws_is_uhd()`.

## What differs by family

| | UHD: VC12-4K | HD: VC41, VC42 and relatives |
|---|---|---|
| Frame layout | Four quarters, one in each of four DMA buffers | Two halves in the channel's one DMA buffer |
| Frame delivery | `hws_video_half_uhd()` | `hws_video_half_hd()` |
| Lengths | `hws_quarter_sizes()` | `hws_half_sizes()` |
| Size change | Writes four lengths, register 9, canary | Writes one length, for that channel |
| Register 9 (DMA limit) | Follows the input, `hws_set_dma_max()` | Fixed, `hws_hd_set_hardware_info()` |
| Channels | 1 | 1, 2 or 4, from the device ID |
| DMA buffers | 4.5 MiB, falling back to 4 MiB | 4 MiB |
| Largest input | 4096×2160, clamped to 3840 when the buffers or card require | 1920×1080; larger shows as no signal |
| Interrupt bits handled | `0x101` | `0xF0F` |
| Status poll | Input only | Also `hws_hd_poll_status()`: rewrites output and picture registers, counts halves on version-0 cards |
| Formats from the card | YUYV | YUYV, YV12, NV12, converted in `hws_convert.c` |
| CPU frames | Staging, scaler | Staging, scaler, YUV, rotation |
| Zero-copy, canary, stale-half knob | Yes | No |
| Hue control | No | Yes |
| Colorimetry | Rec. 709 | BT.601 |
| HDCP register | Always read | Not on version-0 cards |
| Reset on resume | Doesn't call `SetHardWareInfo()`: it would forget the 4.5 MiB buffer size | Calls it, to rewrite register 9 |
| Names | HUHDVideo, HUHDAudio | HVideo, HAudio |

## What was unified

- `hws_scale.c`: the VC41/VC42 scalers were all in the VC12-4K's file, unchanged. Its `VideoScaler()` only adds branches for inputs above 1080p. The HD family now uses this file, so its copies are gone.
- `irqhandler()`: one loop over channels, masked by `irq_known`. On the VC12-4K it does what the old code did for bits 0 and 8. It counts the same bits as unknown, and acknowledges all bits.
- `hws_do_reinit()`, `hws_remove()`, the audio tasklets: the HD versions, which reduce to the VC12-4K's on one channel. Tasklets 1 to 3 exist on a VC12-4K but are never scheduled.
- The half-frame timing fields: `zc_last_ts` and `zc_gap_prev` on the VC12-4K and `last_half_ts` and `half_gap` on the VC41/VC42 did the same job, so they are now `last_half_ts` and `half_gap`.
- `hws_fill_pix()`, `hws_ctrls_init()` and similar: one function with a family check.
- debugfs `status`: the VC41/VC42's per-channel layout, with a zero-copy line on the UHD family.

## Behaviour changes

The merge was meant to keep behaviour per family. These are the exceptions:

| Change | Applies to | Why |
|---|---|---|
| `CheckVideFmt()` takes `engine_lock` | HD | It may restart a channel's capture, which could race with a program stopping capture. The VC12-4K driver already took the lock, in the same order as streaming start. |
| `dma_alloc_video_buffers()` checks the 512 MiB window | HD | A buffer crossing it isn't reachable by the card. It used to go unnoticed; now the driver fails to load. |
| `last_half_ts` and `half_gap` reset at capture start | HD | The VC12-4K driver already did. The first copy after a start is then never counted late, which was also the effect of the old stale value. |
| `m_format[ch].dwHeight` is set | HD | The old code set the width twice. Nothing reads the field. |
| Half-event queue of 32, not 16 | UHD | One size for both. Only changes how far behind the IRQ thread can fall. |
| `hws-audio` workqueue name, `channel n:` in the unsupported-input warning, `status` layout | UHD | One format for both. |
| Probe refuses a device with no table entry | Both | `driver_override` or `new_id` can bind a device outside `hws_pci_table`, whose family is unknown. The separate drivers would carry on with it. |
| `sprintf` to `strscpy` for the ALSA card names | Both | The name is no longer a constant the compiler can check. Same result. |

## ACASIS

Added in 1.3.0, from five archives of ACASIS's (listed below). They are older than the AVMatrix 1.1.0 code, so each was compared with the AVMatrix driver from before its rework (`bd17e06` for the VC12-4K, `7683b9c` for the VC41/VC42). Only what differs from those is new; the rest would undo fixes. All of them carry the same OEM's name (Longtimetech), which the VC12-4K driver has too.

| Archive | What it is | Taken |
|---|---|---|
| `PCIE_1CH_4K60_CAPTURE_CARD_DRIVER_FOR_LINUX` | `HwsUHDX1Capture`, the VC12-4K's IDs, 47 changed lines against `bd17e06` | Nothing: older kernel-compat code only |
| `Linux_PCIE_VS2583_4K60Hz_20260324` | The same driver, 68 changed lines | Nothing: `hws_compat.h`, `bus_info` and control changes that 1.1.0 replaced. Its 7.0 locking lets all of a channel's queues share one mutex; 1.1.0's per-queue lock fixes that |
| `1080P_PCIe_capture_card_drivers_for_Linux` | `HwsCapture`, the VC41/VC42's IDs | `8888:8521` (1 input), `1F33:6502` as 2 inputs, 640×480 output |
| `2CH_4CH_AHD_capture_card_drivers_for_Linux` | `HwsAHDCapture`, from 2023, new IDs, AVideo | The cards, below |
| `VS023_Linux_Driver_20220516` | SMI USB display driver: a self-extracting installer, not a capture driver | Nothing |

The AHD driver's register access, DMA layout, status poll and interrupt handling match the HD family's at `7683b9c`, apart from these, which `hws_card_ahd` carries over:

| AHD driver | Here |
|---|---|
| `SUPPORT_AUDIO` is never defined, so no sound cards, audio interrupts or tasklets | `has_audio = false`, `irq_known = 0x00F` |
| `m_DeviceHW_Version` is always 0, so registers 9, 110-133 and the picture register are never touched | `no_fpga_v1` |
| Frame rate defaults to 30 | `default_fps` |
| Table has no 640×480 | `min_output_w = 720` |

Not carried over:

- The AHD table lists 720×480 at 50 Hz where the others list 720×576. That looks like a slip; AHD cards get 720×576 like the HD family, scaled on the CPU.
- ACASIS's Kylin installers, which load the module from `/opt` to get past Kylin's kysec. `install.sh` only removes what they left. It hasn't been tried on Kylin.

ACASIS's WirePlumber rules (`PluseAudio/`) became `tools/wireplumber-names.sh`, matching this module's name and every card name it can use, not only `HAudio 1` to `4`. It restarts audio only through `systemctl --user`, not by killing processes as ACASIS's script falls back to, and refuses WirePlumber before 0.5, which ignores such rules.

Unknown until someone tests an AHD card: the colorimetry (this driver reports the HDMI cards' BT.601 full range), and whether DV timings make sense for analog inputs. OBS doesn't need them.

## Magewell

Not included. Magewell's Pro Capture cards use their own PCI vendor ID (`1CD7`) and their own driver, `ProCapture`, whose hardware code ships as a prebuilt binary. There's nothing to merge with this driver's code, so those cards stay on Magewell's package.

## What to test on a card

Report the card model, `lspci -nn -d 8888:`, `lspci -nn -d 1f33:` and `sudo dmesg | grep -i hws`.

On any card, for each input:

1. `dmesg` names the right family and input count.
2. `tests/run-baseline.sh /dev/videoN`: the expected frame rate, no duplicates, `v4l2-compliance` finishing.
3. `tests/switchtest.sh <width> <height>`, with `CH=n` on multi-input cards, while switching the source's resolution.
4. OBS with video and audio, then unload or unbind the driver while it captures: no oops.
5. Suspend and resume while capturing.

Then, on a VC12-4K, compare against the 1.1.0 results in `docs/vc12-4k/results.md`, and run `tests/zctest.sh` with `zero_copy=1`. If something regresses, the separate driver at `7a03be9` is the known-good reference.

On an HD card, also run everything in `docs/vc41-vc42/PORT.md`. If something fails, compare with the separate driver at `95231a4`.

If both families are available, run them in one PC: that case is new.
