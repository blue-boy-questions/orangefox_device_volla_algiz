#
# device.mk — Volla Phone Quintus (algiz) · OrangeFox Recovery
#

LOCAL_PATH := device/volla/algiz

# A/B OTA (recovery is part of vendor_boot, not standalone)
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += boot init_boot vendor_boot dtbo vbmeta vbmeta_system vbmeta_vendor

# Dynamic / Virtual A/B
PRODUCT_USE_DYNAMIC_PARTITIONS := true
PRODUCT_VIRTUAL_AB_OTA := true
PRODUCT_VIRTUAL_AB_COMPRESSION := true

# Recovery resources that must live in the vendor_boot recovery fragment.
PRODUCT_PACKAGES += \
    update_engine_sideload

# Logical-partition tooling, handy in recovery for a dynamic-partition device.
PRODUCT_PACKAGES += \
    lptools \
    lpdump

# Soong namespaces (the OrangeFox tree supplies them during sync).
PRODUCT_SOONG_NAMESPACES += $(LOCAL_PATH)

# Device identity
PRODUCT_DEVICE := algiz
PRODUCT_NAME := twrp_algiz
PRODUCT_BRAND := volla
PRODUCT_MODEL := Volla Phone Quintus
PRODUCT_MANUFACTURER := volla

# fastboot / recovery USB identity (from stock recovery props)
PRODUCT_PROPERTY_OVERRIDES += \
    ro.product.first_api_level=31 \
    ro.recovery.usb.vid=18D1 \
    ro.recovery.usb.adb.pid=D001 \
    ro.recovery.usb.fastboot.pid=4EE0

# OrangeFox-specific (OF_*) settings — OF_ vars are allowed in a .mk file.
$(call inherit-product, $(LOCAL_PATH)/fox_algiz.mk)
