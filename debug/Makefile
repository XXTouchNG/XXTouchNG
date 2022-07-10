TARGET := iphone:clang:14.5:13.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard backboardd

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = libdebugwindow

libdebugwindow_FILES = DebugWindow.x
libdebugwindow_FILES += PassWindow.m
libdebugwindow_FILES += AMR_ANSIEscapeHelper.m
libdebugwindow_FILES += GeneratedTouchesDebugWindow.mm
libdebugwindow_FILES += UIView+XXTEToast.m
libdebugwindow_FILES += UIColor+SKColor.m
libdebugwindow_CFLAGS = -fobjc-arc -fobjc-arc-exceptions
libdebugwindow_CFLAGS += -DXXT_VERSION=\"$(XXT_VERSION)\"
GeneratedTouchesDebugWindow.mm_CFLAGS = -fno-objc-arc -DXXT_VERSION=\"$(XXT_VERSION)\"
libdebugwindow_CFLAGS += -I../shared/include/
libdebugwindow_CFLAGS += -Iinclude
libdebugwindow_CFLAGS += -include debug-prefix.pch
libdebugwindow_CCFLAGS = -std=gnu++14
libdebugwindow_PRIVATE_FRAMEWORKS = AppSupport
libdebugwindow_LIBRARIES = substrate rocketbootstrap
libdebugwindow_INSTALL_PATH = /usr/local/lib
libdebugwindow_LIBRARY_EXTENSION = .dylib
include $(THEOS_MAKE_PATH)/library.mk

before-all::
	logos.pl DebugWindow.x > logos__DebugWindow.m

after-all::
	exec "./tbdump.sh"

after-clean::
	rm -f *.tbd logos__*
