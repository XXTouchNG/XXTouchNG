TARGET := iphone:clang:14.5:13.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = elfclient webserv

include $(THEOS)/makefiles/common.mk

TOOL_NAME = webserv

webserv_FILES = WebServ.mm
webserv_FILES += AlertHelperHandlers.m TamperMonkeyHandlers.m
webserv_FILES += CookiesManagerHandlers.m
webserv_FILES += $(wildcard GCDWebServer/*/*.m)
webserv_FILES += $(wildcard GCDWebDAVServer/*.m)
webserv_FILES += $(wildcard PocketSocket/*.m)
webserv_FILES += ../shared/TFShell.mm
PocketSocket/PSWebSocket.m_CFLAGS = -Wno-deprecated-declarations
PocketSocket/PSWebSocketServer.m_CFLAGS = -Wno-deprecated-declarations # -Wno-unused-but-set-variable
webserv_CFLAGS = -fobjc-arc -fobjc-arc-exceptions
webserv_CFLAGS += -DXXT_VERSION=\"$(XXT_VERSION)\"
webserv_CFLAGS += -IGCDWebServer/Core -IGCDWebServer/Requests -IGCDWebServer/Responses
webserv_CFLAGS += -IGCDWebDAVServer/
webserv_CFLAGS += -IPocketSocket/
webserv_CFLAGS += -Wno-unused-function # -Wno-unused-but-set-variable
webserv_CFLAGS += -I../alert/
webserv_CFLAGS += -I../app/
webserv_CFLAGS += -I../debug/          # debug
webserv_CFLAGS += -I../debug/include/  # debug
webserv_CFLAGS += -I../device/
webserv_CFLAGS += -I../device/NHNetworkTime/
webserv_CFLAGS += -I../monkey/
webserv_CFLAGS += -I../proc/
webserv_CFLAGS += -I../screen/
webserv_CFLAGS += -I../screen/include/
webserv_CFLAGS += -I../screen/bridge/
webserv_CFLAGS += -I../supervisor/
webserv_CFLAGS += -I../shared/include/
webserv_CFLAGS += -I../shared/
webserv_CFLAGS += -I../liblua/
webserv_CFLAGS += -Iinclude/
webserv_CFLAGS += -include webserv-prefix.pch
webserv_CCFLAGS = -std=gnu++14
webserv_LDFLAGS = -L$(THEOS_OBJ_DIR)
webserv_FRAMEWORKS = Security
webserv_PRIVATE_FRAMEWORKS = AppSupport
webserv_LIBRARIES = alerthelper deviceconfigurator procqueue screencapture supervisor tampermonkey tfcontainermanager
webserv_LIBRARIES += MobileGestalt xml2
webserv_WEAK_LIBRARIES = ../debug/libdebugwindow  # debug
webserv_CODESIGN_FLAGS = -Sent.plist
webserv_INSTALL_PATH = /usr/local/xxtouch/bin

include $(THEOS_MAKE_PATH)/tool.mk
