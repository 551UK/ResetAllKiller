export TARGET = iphone:clang:latest:16.0
export ARCHS = arm64 arm64e
export THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ResetAllKiller
ResetAllKiller_FILES = Tweak.xm
ResetAllKiller_CFLAGS = -fobjc-arc
ResetAllKiller_FRAMEWORKS = Foundation UIKit

INSTALL_TARGET_PROCESSES = Preferences

include $(THEOS_MAKE_PATH)/tweak.mk
