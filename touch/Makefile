TARGET := iphone:clang:latest:13.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = simulatetouch simulatetouchd

include $(THEOS)/makefiles/common.mk

LUA_MOD_MAKEFILE := $(shell git rev-parse --show-toplevel)/liblua/liblua.mk
include $(LUA_MOD_MAKEFILE)

LIBRARY_NAME = libsimulatetouch

libsimulatetouch_FILES = SimulateTouch.m
libsimulatetouch_FILES += hid/STHIDEventGenerator.m
libsimulatetouch_FILES += bridge/SimulateTouchLuaBridge.mm
libsimulatetouch_FILES += ../shared/luae/luae.mm
libsimulatetouch_CFLAGS = -fobjc-arc -fobjc-arc-exceptions
libsimulatetouch_CFLAGS += -DXXT_VERSION=\"$(XXT_VERSION)\"
libsimulatetouch_CFLAGS += -Wno-unused-variable -Wno-unused-function
libsimulatetouch_CFLAGS += -I../shared/include/
libsimulatetouch_CFLAGS += -I../shared/
libsimulatetouch_CFLAGS += -I../liblua/
libsimulatetouch_CFLAGS += -Ihid -I.
libsimulatetouch_CFLAGS += -I../debug/  # debug
libsimulatetouch_CFLAGS += -I../debug/include/  # debug
libsimulatetouch_CFLAGS += -include touch-prefix.pch
libsimulatetouch_LDFLAGS = $(LUA_MOD_LDFLAGS)
libsimulatetouch_PRIVATE_FRAMEWORKS = AppSupport IOKit IOMobileFrameBuffer IOSurface
libsimulatetouch_LIBRARIES = rocketbootstrap
libsimulatetouch_WEAK_LIBRARIES = ../debug/libdebugwindow  # debug
libsimulatetouch_INSTALL_PATH = /usr/local/lib
libsimulatetouch_LIBRARY_EXTENSION = .dylib
include $(THEOS_MAKE_PATH)/library.mk

TOOL_NAME = simulatetouchd

simulatetouchd_FILES = cli/simulatetouchd.m
simulatetouchd_CFLAGS = -fobjc-arc -fobjc-arc-exceptions
simulatetouchd_CFLAGS += -DXXT_VERSION=\"$(XXT_VERSION)\"
simulatetouchd_CFLAGS += -I../shared/include/
simulatetouchd_LDFLAGS = -L$(THEOS_OBJ_DIR)
simulatetouchd_LDFLAGS += -L../liblua
simulatetouchd_LIBRARIES = simulatetouch lua
simulatetouchd_CODESIGN_FLAGS = -Scli/ent.plist
simulatetouchd_INSTALL_PATH = /usr/local/xxtouch/bin
include $(THEOS_MAKE_PATH)/tool.mk


before-all::
	cp SimulateTouch.h layout/usr/local/include/libsimulatetouch.h
