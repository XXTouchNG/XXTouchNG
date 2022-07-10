TARGET := iphone:clang:14.5:13.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard backboardd

include $(THEOS)/makefiles/common.mk

LUA_MOD_MAKEFILE := $(shell git rev-parse --show-toplevel)/liblua/liblua.mk
include $(LUA_MOD_MAKEFILE)

LIBRARY_NAME = libalerthelper

libalerthelper_FILES = AlertHelper.mm AHWeakObjectWrapper.m
libalerthelper_FILES += $(wildcard ../shared/TFLuaBridge+*.m)
libalerthelper_FILES += ../shared/luae/luae.mm
libalerthelper_CFLAGS = -fobjc-arc -fobjc-arc-exceptions
libalerthelper_CFLAGS += -DXXT_VERSION=\"$(XXT_VERSION)\"
libalerthelper_CFLAGS += -Wno-unused-variable
libalerthelper_CFLAGS += -I../shared/include/
libalerthelper_CFLAGS += -I../shared/
libalerthelper_CFLAGS += -I../liblua/
libalerthelper_CFLAGS += -Iscripts -Iinclude
libalerthelper_CFLAGS += -include alert-prefix.pch
libalerthelper_CFLAGS += -DTF_MIDDLE_MAN
libalerthelper_CCFLAGS = -std=gnu++14
libalerthelper_LDFLAGS = -L../liblua
libalerthelper_LDFLAGS += $(LUA_MOD_LDFLAGS)
libalerthelper_LIBRARIES = substrate rocketbootstrap lua
libalerthelper_FRAMEWORKS = UIKit
libalerthelper_PRIVATE_FRAMEWORKS = AppSupport SpringBoardServices
libalerthelper_INSTALL_PATH = /usr/local/lib
libalerthelper_LIBRARY_EXTENSION = .dylib
include $(THEOS_MAKE_PATH)/library.mk

before-all::
	cd scripts; ./compile_scripts.sh
