TARGET := iphone:clang:14.5:13.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = procqueue procqueued

include $(THEOS)/makefiles/common.mk

LUA_MOD_MAKEFILE := $(shell git rev-parse --show-toplevel)/liblua/liblua.mk
include $(LUA_MOD_MAKEFILE)

LIBRARY_NAME = libprocqueue

libprocqueue_FILES = ProcQueue.m OrderedDictionary.m
libprocqueue_FILES += bridge/ProcQueueLuaBridge.mm
libprocqueue_FILES += ../shared/luae/luae.mm
libprocqueue_CFLAGS = -fobjc-arc -fobjc-arc-exceptions
libprocqueue_CFLAGS += -DXXT_VERSION=\"$(XXT_VERSION)\"
libprocqueue_CFLAGS += -Wno-unused-function -Wno-unused-variable
libprocqueue_CFLAGS += -I../shared/include/
libprocqueue_CFLAGS += -I../shared/
libprocqueue_CFLAGS += -I../liblua/
libprocqueue_CFLAGS += -I.
libprocqueue_CFLAGS += -include proc-prefix.pch
libprocqueue_LDFLAGS = $(LUA_MOD_LDFLAGS)
libprocqueue_PRIVATE_FRAMEWORKS = AppSupport
libprocqueue_LIBRARIES = rocketbootstrap
libprocqueue_INSTALL_PATH = /usr/local/lib
libprocqueue_LIBRARY_EXTENSION = .dylib
include $(THEOS_MAKE_PATH)/library.mk

TOOL_NAME = procqueued

procqueued_FILES = cli/procqueued.m
procqueued_CFLAGS = -fobjc-arc -fobjc-arc-exceptions
procqueued_CFLAGS += -DXXT_VERSION=\"$(XXT_VERSION)\"
procqueued_CFLAGS += -I../shared/include/
procqueued_LDFLAGS = -L$(THEOS_OBJ_DIR)
procqueued_LDFLAGS += -L../liblua
procqueued_LIBRARIES = procqueue lua
ifeq ($(TARGET_CODESIGN),ldid)
procqueued_CODESIGN_FLAGS = -Scli/ent.plist
else
procqueued_CODESIGN_FLAGS = --entitlements cli/ent.plist $(TARGET_CODESIGN_FLAGS)
endif
procqueued_INSTALL_PATH = /usr/local/xxtouch/bin
include $(THEOS_MAKE_PATH)/tool.mk


before-all::
	cp ProcQueue.h layout/usr/local/include/libprocqueue.h
