TARGET := iphone:clang:14.5:13.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

LUA_MOD_MAKEFILE := $(shell git rev-parse --show-toplevel)/liblua/liblua.mk
include $(LUA_MOD_MAKEFILE)

LIBRARY_NAME = libtfcookiesmanager

libtfcookiesmanager_FILES = TFCookiesManager.m
libtfcookiesmanager_FILES += bridge/CookiesManagerLuaBridge.mm
libtfcookiesmanager_FILES += ../shared/luae/luae.mm
libtfcookiesmanager_FILES += $(wildcard CookiesTool/BinaryCodable/BinaryDataCoders/*.swift)
libtfcookiesmanager_FILES += $(wildcard CookiesTool/BinaryCodable/*.swift)
libtfcookiesmanager_FILES += $(filter-out CookiesTool/main.swift, $(wildcard CookiesTool/*.swift))
libtfcookiesmanager_CFLAGS = -fobjc-arc -fobjc-arc-exceptions
libtfcookiesmanager_CFLAGS += -DXXT_VERSION=\"$(XXT_VERSION)\"
libtfcookiesmanager_CFLAGS += -Wno-unused-variable
libtfcookiesmanager_CFLAGS += -I../shared/include/
libtfcookiesmanager_CFLAGS += -I../liblua/
libtfcookiesmanager_CFLAGS += -I../app/
libtfcookiesmanager_CFLAGS += -I.
libtfcookiesmanager_CFLAGS += -include cookies-prefix.pch
libtfcookiesmanager_CCFLAGS = -std=c++14
libtfcookiesmanager_LDFLAGS = $(LUA_MOD_LDFLAGS)
libtfcookiesmanager_LDFLAGS += -L$(THEOS_OBJ_DIR)
libtfcookiesmanager_PRIVATE_FRAMEWORKS = AppSupport
libtfcookiesmanager_LIBRARIES = rocketbootstrap
libtfcookiesmanager_LIBRARIES += tfcontainermanager
libtfcookiesmanager_INSTALL_PATH = /usr/local/lib
libtfcookiesmanager_LIBRARY_EXTENSION = .dylib
libtfcookiesmanager_SWIFT_BRIDGING_HEADER = CookiesTool/CookiesTool-Bridging-Header.h
include $(THEOS_MAKE_PATH)/library.mk


before-all::
	cp TFCookiesManager.h layout/usr/local/include/libtfcookiesmanager.h
