#
# twrp_algiz.mk — OrangeFox product makefile for Volla Phone Quintus (algiz)
#
# OrangeFox is built on the TWRP minimal manifest, so the product + lunch combo
# keep the `twrp_` prefix (lunch combo: twrp_algiz-<release>-eng).
#

# Common AOSP/TWRP base.
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)

# Virtual A/B (Snapshot/compression) — this is a native VAB device.
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/compression.mk)

# Device-specific definitions (also pulls in fox_algiz.mk for the OF_* vars).
$(call inherit-product, device/volla/algiz/device.mk)

# TWRP/OrangeFox common.
$(call inherit-product-if-exists, vendor/twrp/config/common.mk)

PRODUCT_DEVICE := algiz
PRODUCT_NAME := twrp_algiz
PRODUCT_BRAND := volla
PRODUCT_MODEL := Volla Phone Quintus
PRODUCT_MANUFACTURER := volla

PRODUCT_GMS_CLIENTID_BASE := android-volla

# Fingerprint matches stock so OTA/AVB expectations line up during testing.
PRODUCT_BUILD_PROP_OVERRIDES += \
    BuildFingerprint=volla/algiz/algiz:16/BP4A.251205.006/30-volla-16.0:user/release-keys \
    DeviceName=algiz \
    DeviceProduct=algiz
