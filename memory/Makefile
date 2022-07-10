TARGET := iphone:clang:14.5:13.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

LUA_MOD_MAKEFILE := $(shell git rev-parse --show-toplevel)/liblua/liblua.mk
include $(LUA_MOD_MAKEFILE)

LIBRARY_NAME = memory

memory_FILES = MemoryHacker.mm MemoryHackerHelper.mm
memory_FILES += $(wildcard mh_*.m)
memory_FILES += $(wildcard commands/mh_*.m)
memory_FILES += ../shared/luae/luae.mm
memory_CFLAGS = -fobjc-arc -fobjc-arc-exceptions
memory_CFLAGS += -DXXT_VERSION=\"$(XXT_VERSION)\"
memory_CFLAGS += -I../shared/include/
memory_CFLAGS += -I../shared/
memory_CFLAGS += -I../liblua/
memory_CFLAGS += -I.
memory_CFLAGS += -Icommands/
memory_CFLAGS += -include memory-prefix.pch
memory_CCFLAGS = -std=gnu++14
memory_LDFLAGS = $(LUA_MOD_LDFLAGS)
memory_INSTALL_PATH = /usr/local/xxtouch/lib
memory_LIBRARY_EXTENSION = .so
include $(THEOS_MAKE_PATH)/library.mk
