TARGET := iphone:clang:14.5:13.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = TextNow SpringBoard backboardd

include $(THEOS)/makefiles/common.mk

LUA_MOD_MAKEFILE := $(shell git rev-parse --show-toplevel)/liblua/liblua.mk
include $(LUA_MOD_MAKEFILE)

TWEAK_NAME = TextNow

TextNow_FILES = TextNow.mm
TextNow_FILES += $(wildcard ../../shared/TFLuaBridge+*.m)
TextNow_FILES += ../../shared/luae/luae.mm
TextNow_CFLAGS = -fobjc-arc -fobjc-arc-exceptions
TextNow_CFLAGS += -Wno-unused-variable
TextNow_CFLAGS += -I../../shared/include/
TextNow_CFLAGS += -I../../shared/
TextNow_CFLAGS += -I../../liblua/
TextNow_CFLAGS += -include TextNow-Prefix.pch
TextNow_CFLAGS += -DTF_MIDDLE_MAN
TextNow_CCFLAGS = -std=c++14
TextNow_LDFLAGS = $(LUA_MOD_LDFLAGS)
TextNow_LIBRARIES = substrate rocketbootstrap
TextNow_FRAMEWORKS = UIKit
TextNow_PRIVATE_FRAMEWORKS = AppSupport
include $(THEOS_MAKE_PATH)/tweak.mk
