TARGET := iphone:clang:14.5:13.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = authpolicy authpolicyd

include $(THEOS)/makefiles/common.mk

LUA_MOD_MAKEFILE := $(shell git rev-parse --show-toplevel)/liblua/liblua.mk
include $(LUA_MOD_MAKEFILE)

LIBRARY_NAME = libauthpolicy

libauthpolicy_FILES = AuthPolicy.m
libauthpolicy_FILES += bridge/AuthPolicyLuaBridge.mm
libauthpolicy_FILES += ../shared/luae/luae.mm
libauthpolicy_CFLAGS = -fobjc-arc -fobjc-arc-exceptions
libauthpolicy_CFLAGS += -DXXT_VERSION=\"$(XXT_VERSION)\"
libauthpolicy_CFLAGS += -Wno-unused-function -Wno-unused-variable
libauthpolicy_CFLAGS += -I../shared/include/
libauthpolicy_CFLAGS += -I../shared/
libauthpolicy_CFLAGS += -I../liblua/
libauthpolicy_CFLAGS += -Iinclude -I.
libauthpolicy_CFLAGS += -include auth-prefix.pch
libauthpolicy_CCFLAGS = -std=c++14
libauthpolicy_LDFLAGS += $(LUA_MOD_LDFLAGS)
libauthpolicy_PRIVATE_FRAMEWORKS = AppSupport IOKit
libauthpolicy_FRAMEWORKS = CoreTelephony Security
libauthpolicy_LIBRARIES = rocketbootstrap MobileGestalt
libauthpolicy_INSTALL_PATH = /usr/local/lib
libauthpolicy_LIBRARY_EXTENSION = .dylib
include $(THEOS_MAKE_PATH)/library.mk

TOOL_NAME = authpolicyd

authpolicyd_FILES = cli/authpolicyd.m
authpolicyd_CFLAGS = -fobjc-arc -fobjc-arc-exceptions
authpolicyd_CFLAGS += -DXXT_VERSION=\"$(XXT_VERSION)\"
authpolicyd_CFLAGS += -I../shared/include/
authpolicyd_LDFLAGS = -L$(THEOS_OBJ_DIR)
authpolicyd_LDFLAGS += -L../liblua
authpolicyd_LIBRARIES = authpolicy lua
authpolicyd_CODESIGN_FLAGS = -Scli/ent.plist
authpolicyd_INSTALL_PATH = /usr/local/xxtouch/bin
include $(THEOS_MAKE_PATH)/tool.mk


before-all::
	cp AuthPolicy.h layout/usr/local/include/libauthpolicy.h
