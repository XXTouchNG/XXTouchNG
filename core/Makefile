TARGET := iphone:clang:14.5:13.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = lua luac

include $(THEOS)/makefiles/common.mk

TOOL_NAME = lua luac

lua_FILES = ../shared/luae/luae.mm
lua_FILES += cli/extends.mm
lua_FILES += cli/lua.c
# lua_FILES += $(wildcard enc/*.c)
# lua_FILES += $(wildcard enc/*.cpp)
lua_CFLAGS = -fobjc-arc -fobjc-arc-exceptions
lua_CFLAGS += -DXXT_VERSION=\"$(XXT_VERSION)\"
lua_CFLAGS += -Wno-string-plus-int -DLUA_USE_MACOSX -DLUA_COMPAT_MODULE
lua_CFLAGS += -I../shared/include/
lua_CFLAGS += -I../liblua/
lua_CFLAGS += -Iinclude
# lua_CFLAGS += -Ienc
lua_CCFLAGS += -std=c++11
lua_LDFLAGS = -L../liblua
lua_LIBRARIES = readline lua
lua_CODESIGN_FLAGS = -Scli/lua.plist
lua_INSTALL_PATH = /usr/local/xxtouch/bin

luac_FILES = cli/luac.c
# luac_FILES += $(wildcard enc/*.c)
# luac_FILES += $(wildcard enc/*.cpp)
luac_CFLAGS = -Wno-string-plus-int
luac_CFLAGS += -DLUA_USE_MACOSX -DLUA_COMPAT_MODULE -DXXT_VERSION=\"$(XXT_VERSION)\"
luac_CFLAGS += -I../shared/include/
luac_CFLAGS += -I../liblua/
luac_CFLAGS += -Iinclude
# luac_CFLAGS += -Ienc
luac_CCFLAGS += -std=c++11
luac_LDFLAGS = -L../liblua
luac_LIBRARIES = readline lua
luac_CODESIGN_FLAGS = -Scli/luac.plist
luac_INSTALL_PATH = /usr/local/xxtouch/bin

include $(THEOS_MAKE_PATH)/tool.mk
