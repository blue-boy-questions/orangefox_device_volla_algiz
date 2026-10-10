#
# fox_algiz.mk — OrangeFox (OF_*) build settings for Volla Phone Quintus (algiz)
#
# Per the OrangeFox docs, OF_* build vars MAY live in a .mk file (only FOX_*
# vars must be exported from a shell script — those are in vendorsetup.sh).
#

# Maintainer / about screen
OF_MAINTAINER := blue-boy-questions

# Screen geometry (1080x2400 AMOLED). OF_SCREEN_H = full panel height; the
# status-bar indents keep the OrangeFox UI clear of the top cutout.
OF_SCREEN_H := 2400
OF_STATUS_H := 140
OF_HIDE_NOTCH := 1
OF_CLOCK_POS := 1

# Prebuilt stock GKI kernel — avoid the "NO KERNEL CONFIG" error.
OF_FORCE_PREBUILT_KERNEL := 1

# vendor_boot-as-recovery repacking is done with magiskboot.
OF_USE_MAGISKBOOT := 1
OF_USE_MAGISKBOOT_FOR_ALL_PATCHES := 1

# Virtual A/B dynamic super sizing (from the stock super geometry; lets a stock
# ROM re-flash succeed instead of update_engine's calculated allocatable space).
OF_DYNAMIC_FULL_SIZE := 9663676416

# Encryption behaviour — device is FBE v2 + metadata encryption. Keep stock
# forced encryption; do not re-run startup after decrypting; wipe metadata after
# a data format so the next boot re-derives keys cleanly.
OF_KEEP_FORCED_ENCRYPTION := 1
OF_NO_RELOAD_AFTER_DECRYPTION := 1
OF_WIPE_METADATA_AFTER_DATAFORMAT := 1
OF_FORCE_DATA_FORMAT_F2FS := 1
OF_UNBIND_SDCARD_F2FS := 1

# Skip the Treble compatibility check (custom recovery on a vendor ROM).
OF_NO_TREBLE_COMPATIBILITY_CHECK := 1

# Partition tooling useful on a dynamic-partition device.
OF_ENABLE_ALL_PARTITION_TOOLS := 1
OF_USE_LZ4_COMPRESSION := 1

# Fox installer housekeeping
OF_DISABLE_MIUI_SPECIFIC_PARTITIONS := 1
# NOTE: FOX_* vars (e.g. FOX_DELETE_AROMAFM) are intentionally NOT here — the
# OrangeFox build system only processes FOX_* when exported from a shell script,
# never from a .mk file. They live in vendorsetup.sh.
