TARGET := iphone:clang:14.5:13.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

LUA_MOD_MAKEFILE := $(shell git rev-parse --show-toplevel)/liblua/liblua.mk
include $(LUA_MOD_MAKEFILE)

LIBRARY_NAME = pasteboard

pasteboard_FILES = pasteboard.mm
pasteboard_CFLAGS = -fobjc-arc -fobjc-arc-exceptions
pasteboard_CFLAGS += -DXXT_VERSION=\"$(XXT_VERSION)\"
pasteboard_CFLAGS += -DTARGET_OS_IPHONE=1
pasteboard_CFLAGS += -I../shared/include/
pasteboard_CFLAGS += -I../liblua/
pasteboard_CFLAGS += -include pasteboard-prefix.pch
pasteboard_LDFLAGS = $(LUA_MOD_LDFLAGS)
pasteboard_FRAMEWORKS = UIKit
pasteboard_INSTALL_PATH = /usr/local/xxtouch/lib
pasteboard_LIBRARY_EXTENSION = .so
include $(THEOS_MAKE_PATH)/library.mk
