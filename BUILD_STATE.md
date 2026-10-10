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
- **Attempt:** 1
- **Latest run id:** 38055180605 (triggered 2026-10-10T13:17Z, fox_branch=14.1,
  lunch twrp_algiz-ap2a-eng, target vendorbootimage)
- **Branch:** main

## Exact next step
1. Poll run 38055180605. The OrangeFox sync (~85 GB) takes 1-2 h, so the run
   will sit in the "Sync OrangeFox + minimal manifest" step for a long time —
   that is normal, not a hang. Only treat >90 min with no step change as stuck.
2. On failure: `gh run view <id> --log-failed` + the uploaded build-tail.log
   artifact; find the first real error; classify infra vs real (see below);
   smallest fix; commit via `do_commit.py` (or clone+push — see note); re-trigger
   with `gh workflow run build-orangefox.yml -R $R --ref main`.
3. On success: `gh run download <id>`, validate vendor_boot.img
   (`~/.hermes/twrp_algiz/validate_vendor_boot.py <img> --fstab-ref
   stock_recovery.fstab.ref`), confirm the OrangeFox zip + vendor_ramdisk_recovery.cpio
   exist, record sha256, mark DONE, disable the watchdog, final Telegram report.

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
