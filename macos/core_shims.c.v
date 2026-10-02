module macos

// Plain C shims for CoreFoundation/CoreText/CoreGraphics APIs whose signatures
// are awkward to express directly in V. AppKit/Objective-C runtime work lives in
// appkit.v and uses V's macOS message-send bridge.

$if macos || ios {
	#insert "@VMODROOT/macos/core_shims.h"
}
