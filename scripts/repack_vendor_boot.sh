#!/usr/bin/env bash
# repack_vendor_boot.sh — turn the OrangeFox build output into a FLASHABLE vendor_boot.
#
# WHY: on this device vendor_boot carries TWO ramdisk fragments:
#   - type=platform  : the first-stage ramdisk shared by NORMAL boot AND recovery
#                      (175 vendor .ko modules + fstab.mt6877). The AOSP/OrangeFox
#                      build only produces a STRIPPED generic platform fragment
#                      (no modules, no fstab), which breaks first-stage mount ->
#                      the ROM *and* recovery bootloop. We are only porting a
#                      recovery, so normal boot must stay stock: swap the stock
#                      platform fragment back in verbatim.
#   - type=recovery  : the OrangeFox ramdisk. Keep it, but recompress to gzip to
#                      match stock (this MediaTek bootloader can bootloop on an
#                      unexpected vendor_ramdisk compression such as lz4).
# Then re-add an AVB hash footer (algorithm NONE) sized to the 64 MiB partition.
#
# Usage: repack_vendor_boot.sh <WS> <device_tree_dir> <out_img>
set -euo pipefail

WS="${1:?usage: repack_vendor_boot.sh <WS> <device_tree_dir> <out_img>}"
DT="${2:?device tree dir}"
OUTIMG="${3:?output image path}"

PROD="$WS/out/target/product/algiz"
IN="$PROD/vendor_boot.img"
HOSTBIN="$WS/out/host/linux-x86/bin"
MKB_SRC="$WS/system/tools/mkbootimg"

# Prefer the host tools the build already produced; fall back to source scripts.
mkbootimg_bin="$HOSTBIN/mkbootimg"
[ -x "$mkbootimg_bin" ] || mkbootimg_bin="python3 $MKB_SRC/mkbootimg.py"
avbtool_bin="$HOSTBIN/avbtool"
[ -x "$avbtool_bin" ] || avbtool_bin="python3 $WS/external/avb/avbtool.py"

test -f "$IN" || { echo "::error::built vendor_boot.img missing ($IN)"; exit 1; }
PLAT="$DT/prebuilt/stock_vendor_ramdisk_platform.cpio.gz"
DTB="$DT/prebuilt/dtb/stock.dtb"
test -f "$PLAT" || { echo "::error::stock platform fragment prebuilt missing ($PLAT)"; exit 1; }
test -f "$DTB"  || { echo "::error::stock dtb prebuilt missing ($DTB)"; exit 1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

echo "== unpack built vendor_boot =="
PYTHONPATH="$MKB_SRC" python3 "$MKB_SRC/unpack_bootimg.py" --boot_img "$IN" --out "$work" >/dev/null
test -f "$work/vendor_ramdisk01" || { echo "::error::built image has no recovery fragment (vendor_ramdisk01)"; exit 1; }

echo "== normalize recovery fragment compression -> gzip =="
rec="$work/vendor_ramdisk01"
magic="$(head -c4 "$rec" | od -An -tx1 | tr -d ' ')"
case "$magic" in
  022149*|02214c18*|04224d18*) lz4 -d -f "$rec" "$work/recovery.cpio" ;;
  1f8b*)                       gzip -dc "$rec" > "$work/recovery.cpio" ;;
  28b52ffd*)                   zstd -d -f "$rec" -o "$work/recovery.cpio" ;;
  *) echo "   (unknown magic $magic — treating as raw cpio)"; cp "$rec" "$work/recovery.cpio" ;;
esac
gzip -9 -c "$work/recovery.cpio" > "$work/recovery.cpio.gz"

echo "== repack: stock platform fragment + OrangeFox recovery (gzip) + stock dtb =="
# shellcheck disable=SC2086
$mkbootimg_bin \
  --header_version 4 --pagesize 4096 --base 0x40000000 \
  --kernel_offset 0x00080000 --ramdisk_offset 0x11100000 \
  --tags_offset 0x07c80000 --dtb_offset 0x07c80000 \
  --vendor_cmdline 'bootopt=64S3,32N2,64N2 androidboot.serialconsole=0' \
  --dtb "$DTB" \
  --ramdisk_type platform --ramdisk_name '' --vendor_ramdisk_fragment "$PLAT" \
  --ramdisk_type recovery --ramdisk_name recovery --vendor_ramdisk_fragment "$work/recovery.cpio.gz" \
  --vendor_boot "$OUTIMG"

echo "== add AVB hash footer (algorithm NONE), partition_size 67108864 =="
# shellcheck disable=SC2086
$avbtool_bin add_hash_footer --image "$OUTIMG" \
  --partition_name vendor_boot --partition_size 67108864 --hash_algorithm sha256

# sanity: two fragments, platform must equal the stock prebuilt
rm -rf "$work/verify"; mkdir -p "$work/verify"
PYTHONPATH="$MKB_SRC" python3 "$MKB_SRC/unpack_bootimg.py" --boot_img "$OUTIMG" --out "$work/verify" >/dev/null
got_plat="$(sha256sum "$work/verify/vendor_ramdisk00" | awk '{print $1}')"
want_plat="$(sha256sum "$PLAT" | awk '{print $1}')"
if [ "$got_plat" != "$want_plat" ]; then
  echo "::error::platform fragment mismatch after repack ($got_plat != $want_plat)"; exit 1
fi
echo "repacked flashable vendor_boot -> $OUTIMG ($(stat -c%s "$OUTIMG") bytes); platform fragment == stock OK"
