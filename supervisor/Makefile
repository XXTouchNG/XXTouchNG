TARGET := iphone:clang:14.5:13.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = supervisord supervisorctl

include $(THEOS)/makefiles/common.mk

LUA_MOD_MAKEFILE := $(shell git rev-parse --show-toplevel)/liblua/liblua.mk
include $(LUA_MOD_MAKEFILE)

LIBRARY_NAME = libsupervisor

libsupervisor_FILES = Supervisor.m
libsupervisor_FILES += bridge/SupervisorLuaBridge.mm
libsupervisor_FILES += ../shared/TFShell.mm
libsupervisor_CFLAGS = -fobjc-arc -fobjc-arc-exceptions
libsupervisor_CFLAGS += -DXXT_VERSION=\"$(XXT_VERSION)\"
libsupervisor_CFLAGS += -Wno-unused-variable -Wno-unused-function
libsupervisor_CFLAGS += -I../shared/include/
libsupervisor_CFLAGS += -I../shared/
libsupervisor_CFLAGS += -I../liblua/
libsupervisor_CFLAGS += -I../proc/
libsupervisor_CFLAGS += -I.
libsupervisor_CFLAGS += -include supervisor-prefix.pch
libsupervisor_CCFLAGS = -std=c++14
libsupervisor_LDFLAGS = -L$(THEOS_OBJ_DIR)
libsupervisor_LDFLAGS += $(LUA_MOD_LDFLAGS)
libsupervisor_PRIVATE_FRAMEWORKS = AppSupport
libsupervisor_LIBRARIES = procqueue rocketbootstrap
libsupervisor_INSTALL_PATH = /usr/local/lib
libsupervisor_LIBRARY_EXTENSION = .dylib
include $(THEOS_MAKE_PATH)/library.mk

TOOL_NAME = supervisord

supervisord_FILES = cli/supervisord.m
supervisord_CFLAGS = -fobjc-arc -fobjc-arc-exceptions
supervisord_CFLAGS += -DXXT_VERSION=\"$(XXT_VERSION)\"
supervisord_CFLAGS += -I../shared/include/
supervisord_LDFLAGS = -L$(THEOS_OBJ_DIR)
supervisord_LDFLAGS += -L../liblua
supervisord_LIBRARIES = supervisor lua
supervisord_CODESIGN_FLAGS = -Scli/ent.plist
supervisord_INSTALL_PATH = /usr/local/xxtouch/bin
include $(THEOS_MAKE_PATH)/tool.mk


before-all::
	cp Supervisor.h layout/usr/local/include/libsupervisor.h
