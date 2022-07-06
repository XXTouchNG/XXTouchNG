TARGET := iphone:clang:latest:13.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

LUA_MOD_MAKEFILE := $(shell git rev-parse --show-toplevel)/liblua/liblua.mk
include $(LUA_MOD_MAKEFILE)

LIBRARY_NAME = samba

samba_FILES = KxSMBProvider.m
samba_FILES += bridge/KxSMBLuaBridge.mm
samba_FILES += ../shared/luae/luae.mm
samba_CFLAGS = -fobjc-arc -fobjc-arc-exceptions
samba_CFLAGS += -DXXT_VERSION=\"$(XXT_VERSION)\"
samba_CFLAGS += -Wno-nullability-completeness -Wno-pointer-bool-conversion
samba_CFLAGS += -DTARGET_OS_IPHONE=1
samba_CFLAGS += -I../shared/include/
samba_CFLAGS += -I../liblua/
samba_CFLAGS += -I.
samba_CFLAGS += -Iinclude/
samba_CFLAGS += -include samba-prefix.pch
samba_LDFLAGS = -Llib
samba_LDFLAGS += $(LUA_MOD_LDFLAGS)
samba_FRAMEWORKS = Foundation
samba_LIBRARIES = smbclient talloc tdb tevent wbclient iconv resolv z
samba_INSTALL_PATH = /usr/local/xxtouch/lib
samba_LIBRARY_EXTENSION = .so
include $(THEOS_MAKE_PATH)/library.mk
