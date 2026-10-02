#include <AppKit/AppKit.h>
#include <objc/runtime.h>

// Keep a real native window while making the Retina input deterministic.
// Only the test overrides the screen scale; production uses AppKit's value.
static CGFloat witty_initial_size_probe_scale2(id self, SEL command) {
    return 2.0;
}
static inline void* witty_initial_size_test_scale2(void* view) {
    NSWindow* window = [(NSView*)view window];
    Class original = object_getClass(window);
    Class probe = objc_getClass("VTInitialSizeScale2ProbeWindow");
    if (!probe) {
        probe = objc_allocateClassPair(original, "VTInitialSizeScale2ProbeWindow", 0);
        class_addMethod(probe, @selector(backingScaleFactor),
                        (IMP)witty_initial_size_probe_scale2, "d@:");
        objc_registerClassPair(probe);
    }
    object_setClass(window, probe);
    return original;
}
static inline void witty_initial_size_test_restore_class(void* view, void* original) {
    object_setClass([(NSView*)view window], (Class)original);
}
