TARGET := iphone:clang:14.5:13.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = MobileSafari SpringBoard backboardd

include $(THEOS)/makefiles/common.mk

LUA_MOD_MAKEFILE := $(shell git rev-parse --show-toplevel)/liblua/liblua.mk
include $(LUA_MOD_MAKEFILE)

LIBRARY_NAME = libtampermonkey

libtampermonkey_FILES = TamperMonkey.m LogosTamperMonkey.xm
libtampermonkey_FILES += $(wildcard TM*.m)
libtampermonkey_FILES += $(wildcard ../shared/TFLuaBridge+*.m)
libtampermonkey_FILES += ../shared/luae/luae.mm
libtampermonkey_CFLAGS = -fobjc-arc -fobjc-arc-exceptions
libtampermonkey_CFLAGS += -DXXT_VERSION=\"$(XXT_VERSION)\"
libtampermonkey_CFLAGS += -I../shared/include/
libtampermonkey_CFLAGS += -I../shared/
libtampermonkey_CFLAGS += -I../liblua/
libtampermonkey_CFLAGS += -I../auth/
libtampermonkey_CFLAGS += -Iscripts -Iinclude
libtampermonkey_CFLAGS += -include monkey-prefix.pch
libtampermonkey_CFLAGS += -Wno-deprecated-declarations -Wno-unused-variable
libtampermonkey_CFLAGS += -DTF_MIDDLE_MAN
libtampermonkey_CCFLAGS = -std=c++14
libtampermonkey_LDFLAGS = -L../liblua
libtampermonkey_LDFLAGS += -L$(THEOS_OBJ_DIR)
libtampermonkey_LDFLAGS += $(LUA_MOD_LDFLAGS)
libtampermonkey_LIBRARIES = substrate rocketbootstrap lua
libtampermonkey_FRAMEWORKS = UIKit
libtampermonkey_PRIVATE_FRAMEWORKS = AppSupport SpringBoardServices
libtampermonkey_INSTALL_PATH = /usr/local/lib
libtampermonkey_LIBRARY_EXTENSION = .dylib
include $(THEOS_MAKE_PATH)/library.mk


before-all::
	cd scripts; ./compile_scripts.sh
	logos.pl LogosTamperMonkey.xm > logos__LogosTamperMonkey.mm

after-clean::
	rm -f logos__*
