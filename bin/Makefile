TARGET := macosx:clang:latest:11.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

SUBPROJECTS = src/tbdump
include $(THEOS_MAKE_PATH)/aggregate.mk

after-clean::
	rm -f tbdump

