#ifndef WITTY_NATIVE_CONTROLLER_FOCUS_TEST_ABI_H
#define WITTY_NATIVE_CONTROLLER_FOCUS_TEST_ABI_H
#include <Foundation/Foundation.h>
#include <objc/message.h>
#include <objc/runtime.h>

static Class witty_controller_focus_test_class;
static id witty_controller_focus_test_window;
static int witty_controller_focus_test_key_count;
static void witty_controller_focus_test_make_key(id self, SEL command, id sender) {
    if (self == witty_controller_focus_test_window) witty_controller_focus_test_key_count++;
    struct objc_super parent = { self, class_getSuperclass(witty_controller_focus_test_class) };
    ((void (*)(struct objc_super*, SEL, id))objc_msgSendSuper)(&parent, command, sender);
}
static BOOL witty_controller_focus_test_accepts(id self, SEL command) { return YES; }
static void witty_controller_focus_test_launch(void) {
    id app = ((id (*)(id, SEL))objc_msgSend)((id)objc_getClass("NSApplication"), sel_registerName("sharedApplication"));
    ((void (*)(id, SEL))objc_msgSend)(app, sel_registerName("finishLaunching"));
}
static void witty_controller_focus_test_pump(double seconds) {
    id loop = ((id (*)(id, SEL))objc_msgSend)((id)objc_getClass("NSRunLoop"), sel_registerName("currentRunLoop"));
    id until = ((id (*)(id, SEL, double))objc_msgSend)((id)objc_getClass("NSDate"), sel_registerName("dateWithTimeIntervalSinceNow:"), seconds);
    ((void (*)(id, SEL, id))objc_msgSend)(loop, sel_registerName("runUntilDate:"), until);
}
static void witty_controller_focus_test_track(void* window) {
    if (!witty_controller_focus_test_class) {
        // Keep AppKit's existing KVO subclass/observation state intact.
        witty_controller_focus_test_class = objc_getClass("VTTerminalWindow");
        class_addMethod(witty_controller_focus_test_class, sel_registerName("makeKeyAndOrderFront:"), (IMP)witty_controller_focus_test_make_key, "v@:@");
    }
    witty_controller_focus_test_window = (id)window;
    witty_controller_focus_test_key_count = 0;
}
static void* witty_controller_focus_test_responder(void* view, void* window) {
    Class cls = objc_getClass("WittyControllerFocusResponderFixture");
    if (!cls) {
        cls = objc_allocateClassPair(objc_getClass("NSView"), "WittyControllerFocusResponderFixture", 0);
        class_addMethod(cls, sel_registerName("acceptsFirstResponder"), (IMP)witty_controller_focus_test_accepts, "B@:");
        objc_registerClassPair(cls);
    }
    id responder = ((id (*)(id, SEL))objc_msgSend)((id)cls, sel_registerName("alloc"));
    responder = ((id (*)(id, SEL))objc_msgSend)(responder, sel_registerName("init"));
    ((void (*)(id, SEL, id))objc_msgSend)((id)view, sel_registerName("addSubview:"), responder);
    ((BOOL (*)(id, SEL, id))objc_msgSend)((id)window, sel_registerName("makeFirstResponder:"), responder);
    ((void (*)(id, SEL))objc_msgSend)(responder, sel_registerName("release"));
    return (void*)responder;
}
static void* witty_controller_focus_test_first_responder(void* window) {
    return (void*)((id (*)(id, SEL))objc_msgSend)((id)window, sel_registerName("firstResponder"));
}
static int witty_controller_focus_test_calls(void) { return witty_controller_focus_test_key_count; }
#endif
