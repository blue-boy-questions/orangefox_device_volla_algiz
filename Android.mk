# Volla Phone Quintus (algiz) — OrangeFox Recovery device tree
# Platform: MediaTek MT6877 (Dimensity 7050), Android 16, GKI 2.0
# A/B + Virtual A/B, dynamic partitions (super), recovery lives in vendor_boot.
#
# Build: lunch twrp_algiz-<release>-eng && mka adbd vendorbootimage

LOCAL_PATH := $(call my-dir)

ifeq ($(TARGET_DEVICE),algiz)
include $(call all-makefiles-under,$(LOCAL_PATH))
endif
