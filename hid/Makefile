TARGET := iphone:clang:14.5:13.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard backboardd hidrecorder

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = libhidrecorder

libhidrecorder_FILES = HIDRecorder.x HIDRecorderImpl.mm HIDRecorderActivator.m
libhidrecorder_CFLAGS = -fobjc-arc -fobjc-arc-exceptions
libhidrecorder_CFLAGS += -DXXT_VERSION=\"$(XXT_VERSION)\"
libhidrecorder_CFLAGS += -Wno-unused-variable
libhidrecorder_CFLAGS += -I../shared/include/
libhidrecorder_CFLAGS += -I../touch/hid/
libhidrecorder_CFLAGS += -I../supervisor/
libhidrecorder_CFLAGS += -I../device/
libhidrecorder_CFLAGS += -I../proc/
libhidrecorder_CFLAGS += -I.
libhidrecorder_CFLAGS += -include hid-prefix.pch
libhidrecorder_CCFLAGS = -std=c++14
libhidrecorder_LDFLAGS = -L$(THEOS_OBJ_DIR)
libhidrecorder_PRIVATE_FRAMEWORKS = AppSupport IOKit SpringBoardServices
libhidrecorder_LIBRARIES = procqueue supervisor substrate rocketbootstrap
libhidrecorder_WEAK_LIBRARIES = lib/libactivator
libhidrecorder_INSTALL_PATH = /usr/local/lib
libhidrecorder_LIBRARY_EXTENSION = .dylib
include $(THEOS_MAKE_PATH)/library.mk

TOOL_NAME = hidrecorder

hidrecorder_FILES = cli/hidrecorder.m
hidrecorder_CFLAGS = -fobjc-arc -fobjc-arc-exceptions
hidrecorder_CFLAGS += -DXXT_VERSION=\"$(XXT_VERSION)\"
hidrecorder_CFLAGS += -I../shared/include/
hidrecorder_CFLAGS += -I../touch/hid/
hidrecorder_CFLAGS += -I../proc/
hidrecorder_CFLAGS += -I.
hidrecorder_CFLAGS += -include hid-prefix.pch
hidrecorder_LDFLAGS = -L$(THEOS_OBJ_DIR)
hidrecorder_PRIVATE_FRAMEWORKS = IOKit IOMobileFrameBuffer
hidrecorder_LIBRARIES = procqueue lua
hidrecorder_CODESIGN_FLAGS = -Scli/ent.plist
hidrecorder_INSTALL_PATH = /usr/local/xxtouch/bin
include $(THEOS_MAKE_PATH)/tool.mk

before-all::
	logos.pl HIDRecorder.x > logos__HIDRecorder.m

after-clean::
	rm -f logos__*
