# orangefox_device_volla_algiz

**OrangeFox Recovery** device tree for the **Volla Phone Quintus** (codename
`algiz`). This is the OrangeFox counterpart of
[`twrp_device_volla_algiz`](https://github.com/blue-boy-questions/twrp_device_volla_algiz) —
same verified board facts, same stock prebuilts, but driven by the OrangeFox
build system (fox_14.1 experimental manifest) instead of plain TWRP.

| | |
|---|---|
| SoC | MediaTek **Dimensity 7050** (MT6877TT), `ro.board.platform=mt6877` |
| Android | **16** (Volla OS 16 / DariaOS 6, LineageOS-based) |
| Partitioning | **A/B + Virtual A/B**, dynamic partitions (`super`) |
| Boot layout | GKI 2.0: `boot`=kernel-only, `init_boot`=generic ramdisk, `vendor_boot`=platform **+ recovery** ramdisk fragments |
| Screen | 1080×2400 AMOLED, density 477, 120 Hz |
| `/data` | f2fs, FBE v2 (`aes-256-xts`) + metadata encryption |

## The important architectural fact

This device has **no standalone `recovery` partition**. Recovery ships as a
**ramdisk fragment of type `recovery` inside `vendor_boot`** (verified: the
stock `vendor_boot.img` carries two fragments, `platform` 8.8 MB and
`recovery` 17.9 MB). The GKI `boot.img` is kernel-only.

In OrangeFox terms this is a **vendor_boot-as-recovery** build:

- `vendorsetup.sh` exports **`FOX_VENDOR_BOOT_RECOVERY=1`** and
  **`FOX_VIRTUAL_AB_DEVICE=1`**.
- The build target is **`mka adbd vendorbootimage`**, not `recoveryimage`.
- The stock GKI kernel is **reused** (`prebuilt/kernel.gz`) with
  `OF_FORCE_PREBUILT_KERNEL=1` — no kernel source build.
- `init_boot` (where KernelSU/Magisk LKM root lives) is **never touched**.

> `FOX_VENDOR_BOOT_RECOVERY` is flagged *experimental* upstream. With it on,
> OrangeFox disables splash-image swapping, "Flash Current OrangeFox" and
> "Reflash after ROM", and the installer zip bundles a
> `vendor_ramdisk_recovery.cpio` for the fastbootd flash path below.

## Building (GitHub Actions)

The entire build runs on a GitHub Actions runner — see
[`.github/workflows/build-orangefox.yml`](.github/workflows/build-orangefox.yml).
It clones the official OrangeFox `sync` repo, runs `orangefox_sync.sh
--branch 14.1` (which repo-inits the TWRP minimal manifest, applies OrangeFox's
own `system/vold` + manifest patches, and clones the OrangeFox recovery/vendor
trees), drops this tree into `device/volla/algiz`, then builds.

Local-equivalent steps:

```bash
mkdir -p ~/OrangeFox && cd ~/OrangeFox
git clone https://gitlab.com/OrangeFox/sync.git
cd sync
./orangefox_sync.sh --branch 14.1 --path ~/OrangeFox/fox_14.1
# drop this tree to device/volla/algiz, then:
cd ~/OrangeFox/fox_14.1
export ALLOW_MISSING_DEPENDENCIES=true
source build/envsetup.sh
source device/volla/algiz/vendorsetup.sh algiz
lunch twrp_algiz-ap2a-eng
mka adbd vendorbootimage
```

Output: `out/target/product/algiz/vendor_boot.img` (OrangeFox as the recovery
fragment, stock platform fragment + stock kernel preserved), plus — because
`FOX_VENDOR_BOOT_RECOVERY=1` — an OrangeFox installer zip containing
`vendor_ramdisk_recovery.cpio`.

> **Why fox_14.1 and not fox_16.0?** The fox_16.0 route syncs the *complete*
> OrangeFox manifest and currently ships only the Mondrian device tree with no
> minimal-manifest/device-tree workflow, so it is not usable for an arbitrary
> device yet. fox_14.1 is the experimental branch whose minimal-manifest +
> clone-your-own-tree flow matches this port; 12.1 is the fallback if 14.1 is
> unbuildable.

## Flashing (non-destructive test first)

> Flashing a custom recovery requires an **unlocked bootloader**. Because this
> is a vendor_boot-as-recovery device, the **safest** install is the fastbootd
> ramdisk path, which replaces only the recovery ramdisk and not the whole
> vendor_boot. All commands run on your PC.

**Preferred (ramdisk-only) — from the installer zip:**

```bash
# reboot an already-working recovery (or the stock one) to fastbootd, then:
fastboot flash vendor_boot:recovery vendor_ramdisk_recovery.cpio
```

**Whole-partition (one slot, keep a backup first):**

```bash
# back up BOTH slots' stock vendor_boot before anything:
fastboot getvar current-slot
# flash the OTHER (inactive) slot, then switch to it, so slot A stays stock:
fastboot flash vendor_boot_b vendor_boot.img      # if current slot is a
fastboot --disable-verity --disable-verification flash vbmeta vbmeta.img
fastboot set_active b
fastboot reboot recovery
```

The repacked image is signed with AVB algorithm **NONE** (re-signing needs
Volla's private key, which is not public), so `vbmeta` must be flashed with
verity/verification disabled.

**Recovery path:** keep the stock `vendor_boot.img`
(md5 `32adf911d8c2e206dc389019b1007573`) — `fastboot flash vendor_boot
stock-vendor_boot.img` restores stock recovery.

## Status / caveats (untested on device)

The image is produced and structurally validated in CI; it has **not** been
booted on hardware. Likely rough edges, in order of risk:

1. **FBE v2 + metadata decryption** of `/data` — OrangeFox's fox_14.1 vold is
   patched for the split v1/v2 fscrypt API, but on-device key derivation is the
   usual first thing to break on a fresh A14+ port.
2. **vendor_boot-as-recovery itself is experimental upstream** — bootloops are
   possible; use the ramdisk-only fastbootd path for the first test.
3. **Touch** (Goodix `goodix_ts`, module injected into the recovery ramdisk) and
   **display/brightness** on the AMOLED panel.

## Provenance

Stock images and all verified facts come from the TWRP sibling tree
([`device-facts.json`](device-facts.json)), extracted from
[zahedan-vollaos-rom-porter `stable-20260828`](https://github.com/sajjad85gh/zahedan-vollaos-rom-porter/releases/tag/stable-20260828)
(DariaOS 6).
