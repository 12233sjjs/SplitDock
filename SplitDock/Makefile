ARCHS = arm64 arm64e
TARGET = iphone:clang:16.5:16.0
THEOS_PACKAGE_SCHEME = roothide
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SplitDock
SplitDock_FILES = Tweak.xm
SplitDock_FRAMEWORKS = UIKit Foundation
SplitDock_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
