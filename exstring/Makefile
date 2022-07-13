TARGET := iphone:clang:14.5:13.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

LUA_MOD_MAKEFILE := $(shell git rev-parse --show-toplevel)/liblua/liblua.mk
include $(LUA_MOD_MAKEFILE)

LIBRARY_NAME = exstring

exstring_FILES = EasyText.mm
exstring_FILES += NSString+EasyText.m NSData+KKAES.m NSData+KKHASH.m NSString+Random.m
exstring_FILES += ../shared/luae/luae.mm
exstring_CFLAGS = -fobjc-arc -fobjc-arc-exceptions
exstring_CFLAGS += -DXXT_VERSION=\"$(XXT_VERSION)\"
exstring_CFLAGS += -Wno-unused-variable -Wno-unused-function -Wno-deprecated-declarations
exstring_CFLAGS += -I../shared/include/
exstring_CFLAGS += -I../shared/
exstring_CFLAGS += -I../liblua/
exstring_CFLAGS += -include exstring-prefix.pch
exstring_CCFLAGS = -std=c++14
exstring_LDFLAGS = $(LUA_MOD_LDFLAGS)
exstring_INSTALL_PATH = /usr/local/xxtouch/lib/xxtouch
exstring_LIBRARY_EXTENSION = .so
include $(THEOS_MAKE_PATH)/library.mk
