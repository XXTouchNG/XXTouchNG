TARGET := iphone:clang:14.5:13.0
ARCHS = arm64 arm64e

export XXT_VERSION = 3.0.1
include $(THEOS)/makefiles/common.mk

# Targets                    # Archs              # Dependencies
SUBPROJECTS = liblua         # arm64, arm64e      #
SUBPROJECTS += debug         # arm64, arm64e      # substrate, rocketbootstrap
SUBPROJECTS += core          # arm64              # lua
SUBPROJECTS += ext           # arm64              # lua
SUBPROJECTS += exstring      # arm64              # lua
SUBPROJECTS += alert         # arm64, arm64e      # lua, substrate, rocketbootstrap
SUBPROJECTS += app           # arm64              # lua, ext, alert, rocketbootstrap
SUBPROJECTS += cookies       # arm64			  # lua, app, rocketbootstrap
SUBPROJECTS += file          # arm64              # lua
SUBPROJECTS += memory        # arm64              # lua
SUBPROJECTS += monkey        # arm64, arm64e      # lua, substrate, rocketbootstrap
SUBPROJECTS += pasteboard    # arm64              # lua
SUBPROJECTS += touch         # arm64              # lua, debug, rocketbootstrap
SUBPROJECTS += samba         # arm64              # lua
SUBPROJECTS += screen        # arm64, arm64e      # lua, ext, substrate, rocketbootstrap
SUBPROJECTS += device        # arm64, arm64e      # lua, debug, ext, substrate, rocketbootstrap
SUBPROJECTS += proc          # arm64, arm64e      # lua, ext, rocketbootstrap
SUBPROJECTS += supervisor    # arm64, arm64e      # lua, core, proc, rocketbootstrap
SUBPROJECTS += hid           # arm64, arm64e      # proc, supervisor, substrate, rocketbootstrap
SUBPROJECTS += webserv       # arm64              # lua, debug, rocketbootstrap, alert, device, proc, screen, supervisor, monkey, app
SUBPROJECTS += add1s         # arm64
SUBPROJECTS += entitleme     # arm64, arm64e

include $(THEOS_MAKE_PATH)/aggregate.mk


before-all::
	touch layout/Applications/XXTExplorer.app/XXTExplorer
