TARGET := iphone:clang:14.5:13.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

LUA_MOD_MAKEFILE := $(shell git rev-parse --show-toplevel)/liblua/liblua.mk
include $(LUA_MOD_MAKEFILE)

LIBRARY_NAME = libdeviceconfigurator

libdeviceconfigurator_FILES = DeviceConfigurator.m LogosDeviceConfigurator.xm
libdeviceconfigurator_FILES += bridge/DeviceConfiguratorLuaBridge.mm
libdeviceconfigurator_FILES += ../shared/luae/luae.mm
libdeviceconfigurator_FILES += ../shared/TFShell.mm
libdeviceconfigurator_FILES += UIDevice+EquipmentInfo.m
libdeviceconfigurator_FILES += DCUtilNetwork.m DCUtilNetworksManager.m
libdeviceconfigurator_FILES += $(filter-out NHNetworkTime/GCDAsyncSocket.m, $(wildcard NHNetworkTime/*.m))
UIDevice+EquipmentInfo.m_CFLAGS = -fno-objc-arc -DXXT_VERSION=\"$(XXT_VERSION)\"
DCUtilNetwork.m_CFLAGS = -fno-objc-arc -DXXT_VERSION=\"$(XXT_VERSION)\"
DCUtilNetworksManager.m_CFLAGS = -fno-objc-arc -DXXT_VERSION=\"$(XXT_VERSION)\"
libdeviceconfigurator_CFLAGS = -fobjc-arc -fobjc-arc-exceptions
libdeviceconfigurator_CFLAGS += -DXXT_VERSION=\"$(XXT_VERSION)\"
libdeviceconfigurator_CFLAGS += -Wno-unused-function -Wno-unused-variable
libdeviceconfigurator_CFLAGS += -I../shared/include/
libdeviceconfigurator_CFLAGS += -I../shared/
libdeviceconfigurator_CFLAGS += -I../liblua/
libdeviceconfigurator_CFLAGS += -Iinclude/
libdeviceconfigurator_CFLAGS += -INHNetworkTime/
libdeviceconfigurator_CFLAGS += -I.
libdeviceconfigurator_CFLAGS += -I../debug/  # debug
libdeviceconfigurator_CFLAGS += -I../debug/include/  # debug
libdeviceconfigurator_CFLAGS += -include device-prefix.pch
libdeviceconfigurator_CCFLAGS = -std=c++14
libdeviceconfigurator_LDFLAGS = -Llib -L../liblua
libdeviceconfigurator_LDFLAGS += $(LUA_MOD_LDFLAGS)
libdeviceconfigurator_PRIVATE_FRAMEWORKS = AppSupport IOKit MobileWiFi Preferences
libdeviceconfigurator_FRAMEWORKS = CoreTelephony
libdeviceconfigurator_LIBRARIES = substrate rocketbootstrap lua MobileGestalt
libdeviceconfigurator_WEAK_LIBRARIES = ../debug/libdebugwindow  # debug
libdeviceconfigurator_INSTALL_PATH = /usr/local/lib
libdeviceconfigurator_LIBRARY_EXTENSION = .dylib
include $(THEOS_MAKE_PATH)/library.mk


before-all::
	cp DeviceConfigurator.h layout/usr/local/include/libdeviceconfigurator.h
	logos.pl LogosDeviceConfigurator.xm > logos__LogosDeviceConfigurator.mm

after-clean::
	rm -f logos__*
