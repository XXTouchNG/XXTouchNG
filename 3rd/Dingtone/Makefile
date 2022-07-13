TARGET := iphone:clang:14.5:13.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = Dingtone SpringBoard backboardd

include $(THEOS)/makefiles/common.mk

LUA_MOD_MAKEFILE := $(shell git rev-parse --show-toplevel)/liblua/liblua.mk
include $(LUA_MOD_MAKEFILE)

TWEAK_NAME = Dingtone

Dingtone_FILES = Dingtone.mm LogosDingtone.xm
Dingtone_FILES += $(wildcard ../../shared/TFLuaBridge+*.m)
Dingtone_FILES += ../../shared/luae/luae.mm
Dingtone_CFLAGS = -fobjc-arc -fobjc-arc-exceptions
Dingtone_CFLAGS += -Wno-unused-variable
Dingtone_CFLAGS += -I../../shared/include/
Dingtone_CFLAGS += -I../../shared/
Dingtone_CFLAGS += -I../../liblua/
Dingtone_CFLAGS += -include Dingtone-Prefix.pch
Dingtone_CFLAGS += -DTF_MIDDLE_MAN
Dingtone_CCFLAGS = -std=c++14
Dingtone_LDFLAGS = $(LUA_MOD_LDFLAGS)
Dingtone_LIBRARIES = substrate rocketbootstrap
Dingtone_FRAMEWORKS = UIKit
Dingtone_PRIVATE_FRAMEWORKS = AppSupport
include $(THEOS_MAKE_PATH)/tweak.mk

before-all::
	logos.pl LogosDingtone.xm > logos__LogosDingtone.mm

after-clean::
	rm -f logos__*
