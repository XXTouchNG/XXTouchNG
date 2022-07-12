TARGET := iphone:clang:14.5:13.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = webinspectord

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = EntitleMe

EntitleMe_FILES = EntitleMe.x
EntitleMe_CFLAGS = -fobjc-arc
EntitleMe_CFLAGS += -I../shared/include/
EntitleMe_CFLAGS += -include entitleme-prefix.pch

include $(THEOS_MAKE_PATH)/tweak.mk
