TARGET := iphone:clang:14.5:13.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = CashApp SpringBoard backboardd

include $(THEOS)/makefiles/common.mk

LUA_MOD_MAKEFILE := $(shell git rev-parse --show-toplevel)/liblua/liblua.mk
include $(LUA_MOD_MAKEFILE)

TWEAK_NAME = CashApp

CashApp_FILES = CashApp.mm
CashApp_FILES += $(wildcard ../../shared/TFLuaBridge+*.m)
CashApp_FILES += ../../shared/luae/luae.mm
CashApp_CFLAGS = -fobjc-arc -fobjc-arc-exceptions
CashApp_CFLAGS += -Wno-unused-variable
CashApp_CFLAGS += -I../../shared/include/
CashApp_CFLAGS += -I../../shared/
CashApp_CFLAGS += -I../../liblua/
CashApp_CFLAGS += -include CashApp-Prefix.pch
CashApp_CFLAGS += -DTF_MIDDLE_MAN
CashApp_CCFLAGS = -std=gnu++14
CashApp_LDFLAGS = $(LUA_MOD_LDFLAGS)
CashApp_LIBRARIES = substrate rocketbootstrap
CashApp_FRAMEWORKS = UIKit
CashApp_PRIVATE_FRAMEWORKS = AppSupport
include $(THEOS_MAKE_PATH)/tweak.mk
