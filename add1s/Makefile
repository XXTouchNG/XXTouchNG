TARGET := iphone:clang:latest:13.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TOOL_NAME = add1s ohmyjetsam

add1s_FILES = add1s.mm
add1s_CFLAGS = -fobjc-arc
add1s_CFLAGS += -I.
add1s_CCFLAGS = -std=c++11
add1s_CODESIGN_FLAGS = -Sentitlements.plist
add1s_INSTALL_PATH = /usr/local/xxtouch/bin

ohmyjetsam_FILES = ohmyjetsam.mm
ohmyjetsam_CFLAGS = -fobjc-arc
ohmyjetsam_CFLAGS += -I.
ohmyjetsam_CCFLAGS = -std=c++11
ohmyjetsam_CODESIGN_FLAGS = -Sentitlements.plist
ohmyjetsam_INSTALL_PATH = /usr/local/xxtouch/bin

include $(THEOS_MAKE_PATH)/tool.mk
