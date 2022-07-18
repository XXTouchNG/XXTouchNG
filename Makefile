TARGET := iphone:clang:14.5:13.0
ARCHS = arm64 arm64e

ifeq ($(FINALPACKAGE),1)
TARGET_CODESIGN := codesign
TARGET_CODESIGN_FLAGS := -f -s 'Developer ID Application: Lucas Joseph (MB269FV75D)'
endif

export XXT_VERSION = 3.0.1
include $(THEOS)/makefiles/common.mk

# Targets                    # Archs              # Dependencies
SUBPROJECTS = liblua         # arm64, arm64e      #
SUBPROJECTS += auth          # arm64, arm64e      # liblua, rocketbootstrap
SUBPROJECTS += debug         # arm64, arm64e      # substrate, rocketbootstrap
SUBPROJECTS += core          # arm64              # liblua
SUBPROJECTS += ext           # arm64              # liblua
SUBPROJECTS += exstring      # arm64              # liblua
SUBPROJECTS += alert         # arm64, arm64e      # liblua, rocketbootstrap, substrate, auth
SUBPROJECTS += app           # arm64              # liblua, rocketbootstrap, ext, alert
SUBPROJECTS += cookies       # arm64			  # liblua, rocketbootstrap, app
SUBPROJECTS += file          # arm64              # liblua
SUBPROJECTS += memory        # arm64              # liblua
SUBPROJECTS += monkey        # arm64, arm64e      # liblua, rocketbootstrap, substrate, auth
SUBPROJECTS += pasteboard    # arm64              # liblua
SUBPROJECTS += touch         # arm64              # liblua, rocketbootstrap, debug
SUBPROJECTS += samba         # arm64              # liblua
SUBPROJECTS += screen        # arm64, arm64e      # liblua, rocketbootstrap, substrate, ext 
SUBPROJECTS += device        # arm64, arm64e      # liblua, rocketbootstrap, substrate, debug, ext
SUBPROJECTS += proc          # arm64, arm64e      # liblua, rocketbootstrap, ext
SUBPROJECTS += supervisor    # arm64, arm64e      # liblua, rocketbootstrap, core, proc
SUBPROJECTS += hid           # arm64, arm64e      # liblua, rocketbootstrap, substrate, proc, supervisor
SUBPROJECTS += webserv       # arm64              # liblua, rocketbootstrap, debug, alert, device, proc, screen, supervisor, monkey, app
SUBPROJECTS += add1s         # arm64              #
SUBPROJECTS += entitleme     # arm64, arm64e      # liblua, substrate, rocketbootstrap

include $(THEOS_MAKE_PATH)/aggregate.mk


before-all::
	touch layout/Applications/XXTExplorer.app/XXTExplorer
