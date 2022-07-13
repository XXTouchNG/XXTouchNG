TARGET := iphone:clang:14.5:13.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = tfcontainermanager tfcontainermanagerd

include $(THEOS)/makefiles/common.mk

LUA_MOD_MAKEFILE := $(shell git rev-parse --show-toplevel)/liblua/liblua.mk
include $(LUA_MOD_MAKEFILE)

LIBRARY_NAME = libtfcontainermanager

libtfcontainermanager_FILES = TFContainerManager.m TFContainerManager.mm
libtfcontainermanager_FILES += bridge/ContainerManagerLuaBridge.mm
libtfcontainermanager_FILES += $(wildcard ../shared/TFLuaBridge+*.m)
libtfcontainermanager_FILES += ../shared/TFShell.mm
libtfcontainermanager_FILES += ../shared/luae/luae.mm
libtfcontainermanager_CFLAGS = -fobjc-arc -fobjc-arc-exceptions
libtfcontainermanager_CFLAGS += -DXXT_VERSION=\"$(XXT_VERSION)\"
libtfcontainermanager_CFLAGS += -Wno-unused-variable
libtfcontainermanager_CFLAGS += -I../shared/include/
libtfcontainermanager_CFLAGS += -I../shared/
libtfcontainermanager_CFLAGS += -I../liblua/
libtfcontainermanager_CFLAGS += -I.
libtfcontainermanager_CFLAGS += -include app-prefix.pch
libtfcontainermanager_CFLAGS += -DTF_MIDDLE_MAN
libtfcontainermanager_CCFLAGS = -std=c++14
libtfcontainermanager_LDFLAGS = $(LUA_MOD_LDFLAGS)
libtfcontainermanager_PRIVATE_FRAMEWORKS = AppSupport MobileCoreServices MobileContainerManager
libtfcontainermanager_LIBRARIES = rocketbootstrap
libtfcontainermanager_WEAK_LIBRARIES = lib/libapplist
libtfcontainermanager_INSTALL_PATH = /usr/local/lib
libtfcontainermanager_LIBRARY_EXTENSION = .dylib
include $(THEOS_MAKE_PATH)/library.mk

TOOL_NAME = tfcontainermanagerd

tfcontainermanagerd_FILES = cli/tfcontainermanagerd.m
tfcontainermanagerd_CFLAGS = -fobjc-arc -fobjc-arc-exceptions
tfcontainermanagerd_CFLAGS += -DXXT_VERSION=\"$(XXT_VERSION)\"
tfcontainermanagerd_CFLAGS += -I../shared/include/
tfcontainermanagerd_LDFLAGS = -L$(THEOS_OBJ_DIR)
tfcontainermanagerd_LDFLAGS += -L../liblua
tfcontainermanagerd_LIBRARIES = tfcontainermanager lua
tfcontainermanagerd_CODESIGN_FLAGS = -Scli/ent.plist
tfcontainermanagerd_INSTALL_PATH = /usr/local/xxtouch/bin
include $(THEOS_MAKE_PATH)/tool.mk


before-all::
	cp TFContainerManager.h layout/usr/local/include/libtfcontainermanager.h
