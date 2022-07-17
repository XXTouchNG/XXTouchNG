TARGET := iphone:clang:14.5:13.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard screencaptureclient

include $(THEOS)/makefiles/common.mk

LUA_MOD_MAKEFILE := $(shell git rev-parse --show-toplevel)/liblua/liblua.mk
include $(LUA_MOD_MAKEFILE)

LIBRARY_NAME = libscreencapture

libscreencapture_FILES = ScreenCapture.m
libscreencapture_FILES += JSTPixelColor.m JSTPixelImage.m
libscreencapture_FILES += bridge/ScreenCaptureLuaBridge.mm
libscreencapture_FILES += bridge/ScreenCaptureOpenCVWrapper.mm
libscreencapture_FILES += bridge/UIImage+OpenCV.mm
libscreencapture_FILES += bridge/imagick.c
libscreencapture_FILES += ../shared/luae/luae.mm
libscreencapture_CFLAGS = -fobjc-arc -fobjc-arc-exceptions
libscreencapture_CFLAGS += -DXXT_VERSION=\"$(XXT_VERSION)\"
libscreencapture_CFLAGS += -Wno-unused-function -Wno-unused-variable
libscreencapture_CFLAGS += -I../shared/include/
libscreencapture_CFLAGS += -I../shared/
libscreencapture_CFLAGS += -I../liblua/
libscreencapture_CFLAGS += -Iinclude/
libscreencapture_CFLAGS += -I.
libscreencapture_CFLAGS += -include screen-prefix.pch
libscreencapture_CFLAGS += -DMAGICKCORE_HDRI_ENABLE=0 -DMAGICKCORE_QUANTUM_DEPTH=16
libscreencapture_CCFLAGS = -std=c++14
libscreencapture_LDFLAGS = -Llib -Flib -L../liblua
libscreencapture_LDFLAGS += $(LUA_MOD_LDFLAGS)
libscreencapture_FRAMEWORKS = opencv2
libscreencapture_PRIVATE_FRAMEWORKS = AppSupport IOKit IOMobileFrameBuffer IOSurface
libscreencapture_LIBRARIES = substrate rocketbootstrap lua
libscreencapture_LIBRARIES += Magick++ MagickCore MagickWand xml2
libscreencapture_INSTALL_PATH = /usr/local/lib
libscreencapture_LIBRARY_EXTENSION = .dylib
include $(THEOS_MAKE_PATH)/library.mk

TOOL_NAME = screencaptureclient

screencaptureclient_FILES = cli/screencaptureclient.m
screencaptureclient_CFLAGS = -fobjc-arc -fobjc-arc-exceptions
screencaptureclient_CFLAGS += -DXXT_VERSION=\"$(XXT_VERSION)\"
screencaptureclient_CFLAGS += -I../shared/include/
screencaptureclient_LDFLAGS = -L$(THEOS_OBJ_DIR)
screencaptureclient_LDFLAGS += -L../liblua
screencaptureclient_LIBRARIES = screencapture lua
screencaptureclient_CODESIGN_FLAGS = -Scli/ent.plist
screencaptureclient_INSTALL_PATH = /usr/local/xxtouch/bin
include $(THEOS_MAKE_PATH)/tool.mk


before-all::
	cp JST_*.h JSTPixelColor.h JSTPixelImage.h layout/usr/local/include/
	cp ScreenCapture.h layout/usr/local/include/libscreencapture.h
