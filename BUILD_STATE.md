# BUILD_STATE — OrangeFox algiz (vendor_boot-as-recovery) CI build

**Status:** IN_PROGRESS
**Goal:** `.github/workflows/build-orangefox.yml` green on GitHub Actions AND
`out/target/product/algiz/vendor_boot.img` produced + validated. Because
`FOX_VENDOR_BOOT_RECOVERY=1`, an OrangeFox installer zip containing
`vendor_ramdisk_recovery.cpio` is also expected.
**Driver:** Hermes Agent (no local clone; build only on the GitHub runner).
**Repo:** `R=blue-boy-questions/orangefox_device_volla_algiz`

---

## What this is
OrangeFox port of the TWRP algiz tree (`blue-boy-questions/twrp_device_volla_algiz`).
Same device, same verified board facts, same stock prebuilts (kernel.gz, dtbo.img,
stock.dtb, goodix_core.ko) and the same recovery.fstab. Differences from TWRP:
- Built via OrangeFox's official `orangefox_sync.sh --branch 14.1` (clones the
  TWRP minimal manifest, applies OrangeFox's own system/vold + manifest patches,
  then clones OrangeFox bootable/Recovery + vendor/recovery). No local patching.
- vendor_boot-as-recovery: `vendorsetup.sh` exports `FOX_VENDOR_BOOT_RECOVERY=1`
  + `FOX_VIRTUAL_AB_DEVICE=1`; target `mka adbd vendorbootimage`.
- Stock GKI kernel reused via `OF_FORCE_PREBUILT_KERNEL=1`.

## Key difference vs the TWRP build (do not re-fight this)
OrangeFox fox_14.1 `bootable/Recovery/libtar` is ALREADY fscrypt-v2-aware
(verified: block.c/libtar.h use `#ifdef USE_FSCRYPT_POLICY_V1 … #else struct
fscrypt_policy_v2 …`, no `union fscrypt_policy`, no `get_policy_size/descriptor`).
=> The TWRP `fix_libtar_fscrypt_v2.py` patch is NOT needed and is NOT in this
workflow. Do not add it. If a libtar fscrypt error appears, re-read the actual
OrangeFox source first — the API there is different from TeamWin's.

## Current attempt
- **Attempt:** 3
- **Latest run id:** 38084817830 (fox_14.1, now with the repack+auto-prerelease pipeline)
- **Branch:** main
- Attempt 2 (run 38061970554) built GREEN and validated, BUT the raw image
  BOOTLOOPED on device (see "On-device failures" below). The build is not the
  deliverable — a FLASHABLE image is. The workflow now post-processes the raw
  output into a flashable vendor_boot + publishes a pre-release.

## On-device failures (attempt 2 image) — root cause found, do NOT re-fight
The green CI image bootlooped BOTH recovery and the ROM. Two defects in the raw
`mka vendorbootimage` output, both fixed by `scripts/repack_vendor_boot.sh`:
1. **Stripped platform fragment.** vendor_boot carries TWO ramdisk fragments:
   `platform` (type 1) + `recovery` (type 2). The build only emits a STRIPPED
   generic `platform` fragment (3.4 MB, 0 kernel modules, no fstab.mt6877) vs
   stock's 8.8 MB / 175 vendor .ko + fstab. The platform fragment is the
   first-stage ramdisk SHARED with normal boot, so a stripped one breaks
   first-stage mount → ROM *and* recovery bootloop. Fix: swap the stock platform
   fragment back in verbatim (prebuilt `prebuilt/stock_vendor_ramdisk_platform.cpio.gz`,
   sha256 c2edeb8f…). Verified byte-identical to the user's on-device stock.
2. **lz4 recovery fragment.** Our recovery fragment was lz4; stock vendor_boot is
   all gzip. This MediaTek bootloader can bootloop on an unexpected
   vendor_ramdisk compression. Fix: recompress the OrangeFox recovery fragment to
   gzip.
   Plus: **vbmeta must be flashed disabled.** Stock vbmeta has a hash descriptor
   pinning vendor_boot's hash+size; our repack changes both, so stock vbmeta
   rejects it → bootloop. Ship `prebuilt/vbmeta-disabled.img` (AVB flags=3,
   verity+verification disabled); user flashes it alongside.
   The repacked image (stock platform + gzip OF recovery + stock dtb + AVB NONE)
   is `vendor_boot-algiz-FLASHABLE.img`; local sha of the hand-built equivalent
   (FIXED2) d55725b0…; the CI-built one is content-equal (gzip mtime differs).

## STILL UNVERIFIED on device
Even the flashable image is not yet confirmed to BOOT. If it still bootloops,
get the ramoops/pstore console log (device has `ramoops.mem_address=0x48090000`;
helper at /sdcard/recovery/grab-log.sh) — do not keep reflashing blind.

## Latest REAL (build) failure (run 38055180605 — attempt 1): root/vendor symlink clash
Build reached 99% (29994/29996) — the ENTIRE compile succeeded, including libtar
(confirms the fscrypt-v2 analysis: OrangeFox fox_14.1 libtar needs NO patch).
It died in the `ramdisk_files-timestamp` rule that rsyncs the generic root into
the recovery root:
```
could not make way for new symlink: root/vendor
cannot delete non-empty directory: root/vendor
rsync error: some files/attrs were not transferred (code 23) at main.c(1356)
ninja: build stopped: subcommand failed.
```
Root cause: the generic AOSP `root` has `vendor` as a SYMLINK, but the recovery
root already has a real non-empty `vendor/` dir (the health HAL vintf manifest
lands in `recovery/root/vendor/etc/vintf/manifest/android.hardware.health@2.1.xml`),
so rsync can't overwrite the dir with the symlink. Well-known A14+/vendor_boot
recovery packaging clash.
FIX (attempt 2): set `OF_MANUAL_ROOT_VENDOR_ERROR_FIX := 1` in fox_algiz.mk —
OrangeFox's sanctioned workaround (bootable/Recovery Android.mk rm's the stale
root/vendor symlink and recreates it as a dir in LOCAL_POST_INSTALL_CMD before
packaging). Verified the flag is wired in the fox_14.1 OrangeFox Android.mk.

## Exact next step
1. (this commit) land OF_MANUAL_ROOT_VENDOR_ERROR_FIX + state.
2. Trigger `gh workflow run build-orangefox.yml -R $R --ref main` (defaults).
   Record run id. Each run re-syncs (~1 h); expect ~1h15m total.
3. Poll. On the next failure, diagnose from build-tail.log; on success, validate.

## Hypotheses already tried that did NOT work (never repeat)
- **H1** (attempt 1, run 38055180605): first build with no root/vendor handling.
  FAILED at 99% packaging: rsync code 23, root/vendor symlink-vs-dir clash. The
  COMPILE was 100% clean (no libtar/fscrypt errors — do NOT add the TWRP libtar
  patch here). Fixed in attempt 2 with OF_MANUAL_ROOT_VENDOR_ERROR_FIX.

## Failure classification
- **Infrastructure** (retry, no code change): timeouts, `Could not resolve host`,
  connection reset, HTTP 5xx/429, incomplete repo sync, runner OOM/cancelled,
  runner ENOSPC → backoff then rerun. The fox_14.1 sync is big; a half-synced
  tree is infra, just rerun.
- **Real build** (fix code): Soong/Kati/ninja errors, missing module/file,
  BoardConfig/device.mk/vendorsetup inconsistency, bad prebuilt path, lunch
  release-token mismatch, OrangeFox build-var misuse (FOX_* in a .mk file is
  silently ignored — those MUST be in vendorsetup.sh).

## Risks specific to this build (watch for, don't pre-patch)
- Disk/ENOSPC: fox_14.1 needs ~85 GB synced + out/ on one fs. The workflow frees
  toolchain dirs + 16 G swap. If ENOSPC recurs, free more / shrink swap further.
- `FOX_VENDOR_BOOT_RECOVERY` is experimental upstream; its mkbootimg/magiskboot
  repack of the recovery fragment may surface new errors not seen in TWRP.
- vendorsetup.sh auto-sourcing: the Build step explicitly `source`s it so the
  FOX_* vars are set even if the manifest no longer auto-sources device scripts.
- lunch combo: fox_14.1 uses the ap2a release token (twrp_algiz-ap2a-eng); the
  workflow probes ap2a→ap1a→trunk_staging→trunk→bp1a→next→(bare) as fallback.

## Commit note
`do_commit.py` (Git Data API) hit HTTP 400 on the big binary blobs for this
repo's first commit; a shallow `gh repo clone` + `git add`/`commit`/`push`
(gh is the git credential helper via `gh auth setup-git`) worked. For small
text-only edits (BUILD_STATE.md, workflow tweaks) `do_commit.py` is fine; for
anything touching the prebuilt binaries, use the clone+push path.

## Hypotheses already tried that did NOT work (never repeat)
- (none yet — attempt 1 in flight)

## Validation checklist — run after a green build
1. `vendor_boot.img` exists, size plausible (< 64 MiB partition).
2. header v4; two fragments: `platform` (stock) + `recovery` (OrangeFox).
3. stock kernel + dtb intact.
4. recovery fragment: OrangeFox binary, fstab matching stock_recovery.fstab.ref.
5. OrangeFox installer zip + `vendor_ramdisk_recovery.cpio` present.
6. AVB signed algorithm NONE.
7. report `sha256sum`.
