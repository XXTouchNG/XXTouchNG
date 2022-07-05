TARGET := iphone:clang:latest:13.0
ARCHS = arm64 arm64e
DEBUG = 0

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = liblua

liblua_FILES = $(wildcard *.c)
liblua_CFLAGS = -Wno-string-plus-int
liblua_CFLAGS += -DLUA_USE_MACOSX -DLUA_COMPAT_5_1 -DLUA_COMPAT_5_2
liblua_INSTALL_PATH = /usr/lib
liblua_LIBRARY_EXTENSION = .dylib
include $(THEOS_MAKE_PATH)/library.mk

after-all::
	exec "./tbdump.sh"

after-clean::
	rm -f *.tbd
