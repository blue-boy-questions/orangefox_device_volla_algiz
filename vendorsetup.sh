#
#	This file is part of the OrangeFox Recovery Project
#	Copyright (C) 2020-2026 The OrangeFox Recovery Project
#	SPDX-License-Identifier: GPL-3.0-or-later
#
#	FOX_* build vars MUST be exported from a shell script (this file); the
#	OrangeFox build system does NOT process FOX_* vars placed in any .mk file.
#	OF_* vars live in fox_algiz.mk (inherited from device.mk).
#
FDEVICE="algiz"

fox_get_target_device() {
    local chkdev=$(echo "$BASH_SOURCE" | grep -w $FDEVICE)
    if [ -n "$chkdev" ]; then
        FOX_BUILD_DEVICE="$FDEVICE"
    else
        chkdev=$(set | grep BASH_ARGV | grep -w $FDEVICE)
        [ -n "$chkdev" ] && FOX_BUILD_DEVICE="$FDEVICE"
    fi
}

if [ -z "$1" -a -z "$FOX_BUILD_DEVICE" ]; then
    fox_get_target_device
fi

if [ "$1" = "$FDEVICE" -o "$FOX_BUILD_DEVICE" = "$FDEVICE" ]; then
    export LC_ALL="C"

    # ---- Device topology -------------------------------------------------
    # Native Android 11+ Virtual A/B device. Setting this auto-enables
    # FOX_AB_DEVICE and FOX_VANILLA_BUILD.
    export FOX_VIRTUAL_AB_DEVICE=1

    # ---- vendor_boot-as-recovery (THE key flag for this device) ----------
    # algiz has NO standalone recovery partition; recovery is a ramdisk
    # fragment of type `recovery` inside the hdr-v4 vendor_boot. This makes
    # OrangeFox build the vendor_boot recovery ramdisk and emit
    # vendor_ramdisk_recovery.cpio in the installer zip.
    # (Experimental upstream — see README for the fastbootd flash procedure.)
    export FOX_VENDOR_BOOT_RECOVERY=1
    # vendor_boot partition is at the default /dev/block/by-name/vendor_boot,
    # so FOX_RECOVERY_VENDOR_BOOT_PARTITION is intentionally left unset.

    # ---- Prebuilt stock GKI kernel ---------------------------------------
    export OF_FORCE_PREBUILT_KERNEL=1

    # ---- Host-binary helpers (standard OrangeFox set) --------------------
    export FOX_USE_TAR_BINARY=1
    export FOX_USE_SED_BINARY=1
    export FOX_USE_LZ4_BINARY=1
    export FOX_USE_ZSTD_BINARY=1
    export FOX_USE_XZ_UTILS=1
    export FOX_USE_BUSYBOX_BINARY=1
    export FOX_USE_FSCK_EROFS_BINARY=1
    export FOX_USE_UPDATED_MAGISKBOOT=1

    # ---- Installer / UX --------------------------------------------------
    export FOX_DELETE_AROMAFM=1
    export FOX_ENABLE_APP_MANAGER=1

    # ---- Target identity (for the device-match guard in the ROM) ---------
    export FOX_TARGET_DEVICES="algiz,quintus"
fi
#
