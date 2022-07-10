TARGET := iphone:clang:14.5:13.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

LUA_MOD_MAKEFILE := $(shell git rev-parse --show-toplevel)/liblua/liblua.mk
include $(LUA_MOD_MAKEFILE)

LIBRARY_NAME = file

file_FILES = file.mm FileHash.m
file_FILES += ../shared/luae/luae.mm
file_CFLAGS = -fobjc-arc -fobjc-arc-exceptions
file_CFLAGS += -DXXT_VERSION=\"$(XXT_VERSION)\"
file_CFLAGS += -DTARGET_OS_IPHONE=1 -DNDEBUG
file_CFLAGS += -Wno-deprecated-declarations
file_CFLAGS += -I../shared/include/
file_CFLAGS += -I../liblua/
file_CFLAGS += -include file-prefix.pch
file_LDFLAGS += $(LUA_MOD_LDFLAGS)
file_FRAMEWORKS = Foundation
file_INSTALL_PATH = /usr/local/xxtouch/lib
file_LIBRARY_EXTENSION = .so
include $(THEOS_MAKE_PATH)/library.mk
