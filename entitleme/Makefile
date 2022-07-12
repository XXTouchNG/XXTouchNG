TARGET := iphone:clang:14.5:13.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = akd webinspectord

include $(THEOS)/makefiles/common.mk

LUA_MOD_MAKEFILE := $(shell git rev-parse --show-toplevel)/liblua/liblua.mk
include $(LUA_MOD_MAKEFILE)

LIBRARY_NAME = libentitleme

libentitleme_FILES = EntitleMe.m
libentitleme_FILES += bridge/EntitleMeLuaBridge.mm
libentitleme_FILES += ../shared/luae/luae.mm
libentitleme_CFLAGS = -fobjc-arc -fobjc-arc-exceptions
libentitleme_CFLAGS += -DXXT_VERSION=\"$(XXT_VERSION)\"
libentitleme_CFLAGS += -I../shared/include/
libentitleme_CFLAGS += -I../liblua/
libentitleme_CFLAGS += -I.
libentitleme_CFLAGS += -include entitleme-prefix.pch
libentitleme_LDFLAGS = -L../liblua
libentitleme_LDFLAGS += $(LUA_MOD_LDFLAGS)
libentitleme_LIBRARIES = substrate rocketbootstrap lua
libentitleme_FRAMEWORKS = Foundation
libentitleme_PRIVATE_FRAMEWORKS = AppSupport
libentitleme_INSTALL_PATH = /usr/lib
libentitleme_LIBRARY_EXTENSION = .dylib

include $(THEOS_MAKE_PATH)/library.mk
