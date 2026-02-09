// appkit.m — Objective-C helpers for vterminal's macOS window.
// Compiled automatically by V via #include in appkit.v.

#import <AppKit/AppKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CoreText/CoreText.h>
#import <CoreGraphics/CoreGraphics.h>
#import <IOSurface/IOSurfaceRef.h>
#import <CoreVideo/CoreVideo.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#import <dispatch/dispatch.h>
#import <os/log.h>
#import <os/signpost.h>

// ============================================================
// Callback types (implemented in V) — each receives userdata
// ============================================================

typedef void (*vt_draw_fn)(void *userdata, CGContextRef ctx, double width, double height);
typedef void (*vt_key_fn)(void *userdata, unsigned short keycode, unsigned long modflags,
                          const char *chars, int len,
                          const char *uchars, int ulen,
                          bool is_repeat);
typedef void (*vt_resize_fn)(void *userdata, double width, double height);
typedef void (*vt_app_ready_fn)(void);
typedef void (*vt_paste_fn)(void *userdata, const char *text, int len);
typedef void (*vt_action_fn)(void *userdata, int action_id);
typedef void (*vt_mouse_fn)(void *userdata, int event_type, double x, double y,
                            unsigned long modflags);

static vt_draw_fn   g_draw_cb   = NULL;
static vt_key_fn    g_key_cb    = NULL;
static vt_resize_fn g_resize_cb = NULL;
static vt_app_ready_fn g_ready_cb = NULL;
static vt_paste_fn  g_paste_cb  = NULL;
static vt_action_fn g_action_cb = NULL;
static vt_mouse_fn  g_mouse_cb  = NULL;

enum {
    VT_ACTION_COPY       = 1,
    VT_ACTION_SELECT_ALL = 2,
    VT_ACTION_NEW_TAB    = 3,
    VT_ACTION_CLOSE_TAB  = 4,
};

// ============================================================
// VTTerminalView — custom NSView with per-view userdata
// ============================================================

@interface VTTerminalView : NSView {
    void *vtUserdata;
    CAMetalLayer *metalLayer;
    id<MTLDevice> metalDevice;
    id<MTLCommandQueue> metalQueue;
}
- (void)setVtUserdata:(void *)ptr;
- (void *)vtUserdata;
- (CAMetalLayer *)metalLayer;
- (id<MTLDevice>)metalDevice;
- (id<MTLCommandQueue>)metalQueue;
@end

@implementation VTTerminalView

- (void)setVtUserdata:(void *)ptr { vtUserdata = ptr; }
- (void *)vtUserdata { return vtUserdata; }
- (CAMetalLayer *)metalLayer { return metalLayer; }
- (id<MTLDevice>)metalDevice { return metalDevice; }
- (id<MTLCommandQueue>)metalQueue { return metalQueue; }

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        // Set up Metal device and queue (layer is created but not yet
        // attached as the view's backing layer — drawRect still uses
        // CGContext. Call vt_metal_activate_layer() to switch to Metal.)
        metalDevice = MTLCreateSystemDefaultDevice();
        if (metalDevice) {
            metalQueue = [metalDevice newCommandQueue];
            metalLayer = [CAMetalLayer layer];
            metalLayer.device = metalDevice;
            metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
            metalLayer.framebufferOnly = YES;
            metalLayer.contentsScale = [[NSScreen mainScreen] backingScaleFactor];
        }
    }
    return self;
}

- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)canBecomeKeyView { return YES; }

- (void)drawRect:(NSRect)dirtyRect {
    if (!g_draw_cb || !vtUserdata) {
        [[NSColor blackColor] setFill];
        NSRectFill(dirtyRect);
        return;
    }
    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
    NSRect bounds = [self bounds];
    g_draw_cb(vtUserdata, ctx, bounds.size.width, bounds.size.height);
}

- (void)keyDown:(NSEvent *)event {
    if (!g_key_cb || !vtUserdata) return;

    NSString *chars = [event characters] ?: @"";
    const char *utf8 = [chars UTF8String];
    int utf8_len = (int)strlen(utf8);

    NSString *uchars = [event charactersIgnoringModifiers] ?: @"";
    const char *uutf8 = [uchars UTF8String];
    int uutf8_len = (int)strlen(uutf8);

    g_key_cb(vtUserdata, [event keyCode], [event modifierFlags],
             utf8, utf8_len, uutf8, uutf8_len,
             [event isARepeat]);
}

- (void)flagsChanged:(NSEvent *)event {
    (void)event;
}

// ---- Mouse event handlers ----
// event_type: 0=left_down, 1=left_up, 2=left_dragged, 3=right_down, 4=right_up, 5=moved

- (void)mouseDown:(NSEvent *)event {
    if (!g_mouse_cb || !vtUserdata) return;
    NSPoint loc = [self convertPoint:[event locationInWindow] fromView:nil];
    g_mouse_cb(vtUserdata, 0, loc.x, loc.y, [event modifierFlags]);
}

- (void)mouseUp:(NSEvent *)event {
    if (!g_mouse_cb || !vtUserdata) return;
    NSPoint loc = [self convertPoint:[event locationInWindow] fromView:nil];
    g_mouse_cb(vtUserdata, 1, loc.x, loc.y, [event modifierFlags]);
}

- (void)mouseDragged:(NSEvent *)event {
    if (!g_mouse_cb || !vtUserdata) return;
    NSPoint loc = [self convertPoint:[event locationInWindow] fromView:nil];
    g_mouse_cb(vtUserdata, 2, loc.x, loc.y, [event modifierFlags]);
}

- (void)rightMouseDown:(NSEvent *)event {
    if (!g_mouse_cb || !vtUserdata) return;
    NSPoint loc = [self convertPoint:[event locationInWindow] fromView:nil];
    g_mouse_cb(vtUserdata, 3, loc.x, loc.y, [event modifierFlags]);
}

- (void)rightMouseUp:(NSEvent *)event {
    if (!g_mouse_cb || !vtUserdata) return;
    NSPoint loc = [self convertPoint:[event locationInWindow] fromView:nil];
    g_mouse_cb(vtUserdata, 4, loc.x, loc.y, [event modifierFlags]);
}

- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    if (!vtUserdata) return;  // view is being torn down
    if (metalLayer) {
        CGFloat scale = metalLayer.contentsScale;
        metalLayer.drawableSize = CGSizeMake(newSize.width * scale, newSize.height * scale);
    }
    if (g_resize_cb) {
        g_resize_cb(vtUserdata, newSize.width, newSize.height);
    }
}

- (void)viewDidChangeBackingProperties {
    [super viewDidChangeBackingProperties];
    if (metalLayer) {
        CGFloat scale = [[self window] backingScaleFactor];
        metalLayer.contentsScale = scale;
        NSSize size = [self bounds].size;
        metalLayer.drawableSize = CGSizeMake(size.width * scale, size.height * scale);
    }
}

// ---- Menu action handlers ----

- (void)copy:(id)sender {
    (void)sender;
    if (g_action_cb && vtUserdata) g_action_cb(vtUserdata, VT_ACTION_COPY);
}

- (void)paste:(id)sender {
    (void)sender;
    if (!g_paste_cb || !vtUserdata) return;
    NSString *text = [[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString];
    if (text) {
        const char *utf8 = [text UTF8String];
        g_paste_cb(vtUserdata, utf8, (int)strlen(utf8));
    }
}

- (void)selectAll:(id)sender {
    (void)sender;
    if (g_action_cb && vtUserdata) g_action_cb(vtUserdata, VT_ACTION_SELECT_ALL);
}

- (void)vtNewTab:(id)sender {
    (void)sender;
    if (g_action_cb && vtUserdata) g_action_cb(vtUserdata, VT_ACTION_NEW_TAB);
}

- (void)vtCloseTab:(id)sender {
    (void)sender;
    if (g_action_cb && vtUserdata) g_action_cb(vtUserdata, VT_ACTION_CLOSE_TAB);
}

@end

// ============================================================
// VTAppDelegate
// ============================================================

@interface VTAppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation VTAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    [NSApp activateIgnoringOtherApps:YES];
    if (g_ready_cb) {
        g_ready_cb();
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    (void)sender;
    return YES;
}

@end

// ============================================================
// Global state
// ============================================================

static NSWindow        *vt_g_window   = nil;  // first window (tab group anchor)
static VTAppDelegate   *vt_g_delegate = nil;

// ============================================================
// Callback setters
// ============================================================

void vt_set_draw_callback(vt_draw_fn cb) {
    g_draw_cb = cb;
}

void vt_set_key_callback(vt_key_fn cb) {
    g_key_cb = cb;
}

void vt_set_resize_callback(vt_resize_fn cb) {
    g_resize_cb = cb;
}

void vt_set_ready_callback(vt_app_ready_fn cb) {
    g_ready_cb = cb;
}

void vt_set_paste_callback(vt_paste_fn cb) {
    g_paste_cb = cb;
}

void vt_set_action_callback(vt_action_fn cb) {
    g_action_cb = cb;
}

void vt_set_mouse_callback(vt_mouse_fn cb) {
    g_mouse_cb = cb;
}

void vt_clipboard_set_text(const char *text, int len) {
    if (!text || len <= 0) return;
    NSString *str = [[NSString alloc] initWithBytes:text length:len encoding:NSUTF8StringEncoding];
    if (str) {
        NSPasteboard *pb = [NSPasteboard generalPasteboard];
        [pb clearContents];
        [pb setString:str forType:NSPasteboardTypeString];
    }
}

// ============================================================
// Per-view userdata accessors
// ============================================================

void vt_view_set_userdata(void *view, void *ptr) {
    [(__bridge VTTerminalView *)view setVtUserdata:ptr];
}

void* vt_view_get_userdata(void *view) {
    return [(__bridge VTTerminalView *)view vtUserdata];
}

// ============================================================
// C-linkage functions called from V
// ============================================================

void vt_app_init(void) {
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

    NSMenu *menuBar = [[NSMenu alloc] init];

    // ---- App menu (vterminal) ----
    NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
    [menuBar addItem:appMenuItem];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"vterminal"];
    [appMenu addItemWithTitle:@"About vterminal"
                       action:@selector(orderFrontStandardAboutPanel:)
                keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"Hide vterminal"
                       action:@selector(hide:)
                keyEquivalent:@"h"];
    NSMenuItem *hideOthers = [appMenu addItemWithTitle:@"Hide Others"
                                                action:@selector(hideOtherApplications:)
                                         keyEquivalent:@"h"];
    [hideOthers setKeyEquivalentModifierMask:NSEventModifierFlagCommand | NSEventModifierFlagOption];
    [appMenu addItemWithTitle:@"Show All"
                       action:@selector(unhideAllApplications:)
                keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"Quit vterminal"
                       action:@selector(terminate:)
                keyEquivalent:@"q"];
    [appMenuItem setSubmenu:appMenu];

    // ---- File menu ----
    NSMenuItem *fileMenuItem = [[NSMenuItem alloc] init];
    [menuBar addItem:fileMenuItem];
    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
    [fileMenu addItemWithTitle:@"New Tab"
                        action:@selector(vtNewTab:)
                 keyEquivalent:@"t"];
    [fileMenu addItemWithTitle:@"Close Tab"
                        action:@selector(vtCloseTab:)
                 keyEquivalent:@"w"];
    [fileMenuItem setSubmenu:fileMenu];

    // ---- Edit menu ----
    NSMenuItem *editMenuItem = [[NSMenuItem alloc] init];
    [menuBar addItem:editMenuItem];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
    [editMenu addItemWithTitle:@"Copy"
                        action:@selector(copy:)
                 keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Paste"
                        action:@selector(paste:)
                 keyEquivalent:@"v"];
    [editMenu addItemWithTitle:@"Select All"
                        action:@selector(selectAll:)
                 keyEquivalent:@"a"];
    [editMenuItem setSubmenu:editMenu];

    // ---- View menu ----
    NSMenuItem *viewMenuItem = [[NSMenuItem alloc] init];
    [menuBar addItem:viewMenuItem];
    NSMenu *viewMenu = [[NSMenu alloc] initWithTitle:@"View"];
    NSMenuItem *fullscreen = [viewMenu addItemWithTitle:@"Toggle Full Screen"
                                                action:@selector(toggleFullScreen:)
                                         keyEquivalent:@"f"];
    [fullscreen setKeyEquivalentModifierMask:NSEventModifierFlagCommand | NSEventModifierFlagControl];
    [viewMenuItem setSubmenu:viewMenu];

    // ---- Window menu ----
    NSMenuItem *windowMenuItem = [[NSMenuItem alloc] init];
    [menuBar addItem:windowMenuItem];
    NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];
    [windowMenu addItemWithTitle:@"Minimize"
                          action:@selector(performMiniaturize:)
                   keyEquivalent:@"m"];
    [windowMenu addItemWithTitle:@"Zoom"
                          action:@selector(performZoom:)
                   keyEquivalent:@""];
    [windowMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *prevTab = [windowMenu addItemWithTitle:@"Show Previous Tab"
                                               action:@selector(selectPreviousTab:)
                                        keyEquivalent:@"["];
    [prevTab setKeyEquivalentModifierMask:NSEventModifierFlagCommand | NSEventModifierFlagShift];
    NSMenuItem *nextTab = [windowMenu addItemWithTitle:@"Show Next Tab"
                                               action:@selector(selectNextTab:)
                                        keyEquivalent:@"]"];
    [nextTab setKeyEquivalentModifierMask:NSEventModifierFlagCommand | NSEventModifierFlagShift];
    [windowMenu addItem:[NSMenuItem separatorItem]];
    [windowMenu addItemWithTitle:@"Bring All to Front"
                          action:@selector(arrangeInFront:)
                   keyEquivalent:@""];
    [windowMenuItem setSubmenu:windowMenu];
    [NSApp setWindowsMenu:windowMenu];

    [NSApp setMainMenu:menuBar];

    vt_g_delegate = [[VTAppDelegate alloc] init];
    [NSApp setDelegate:vt_g_delegate];
}

void vt_app_run(void) {
    [NSApp run];
}

void* vt_create_window(int w, int h, const char *title) {
    NSRect frame = NSMakeRect(100, 100, w, h);
    NSUInteger style = NSWindowStyleMaskTitled
                     | NSWindowStyleMaskClosable
                     | NSWindowStyleMaskMiniaturizable
                     | NSWindowStyleMaskResizable;

    vt_g_window = [[NSWindow alloc] initWithContentRect:frame
                                           styleMask:style
                                             backing:NSBackingStoreBuffered
                                               defer:NO];
    [vt_g_window setTitle:[NSString stringWithUTF8String:title]];
    [vt_g_window setMinSize:NSMakeSize(200, 100)];
    // Allow automatic tabbing so macOS groups tabs together
    [vt_g_window setTabbingMode:NSWindowTabbingModePreferred];

    VTTerminalView *view = [[VTTerminalView alloc] initWithFrame:frame];
    [vt_g_window setContentView:view];
    [vt_g_window makeFirstResponder:view];
    [vt_g_window makeKeyAndOrderFront:nil];

    return (__bridge void*)view;
}

// ============================================================
// Tab management
// ============================================================

void* vt_new_tab(int w, int h, const char *title) {
    if (!vt_g_window) return NULL;

    NSRect frame = NSMakeRect(100, 100, w, h);
    NSUInteger style = NSWindowStyleMaskTitled
                     | NSWindowStyleMaskClosable
                     | NSWindowStyleMaskMiniaturizable
                     | NSWindowStyleMaskResizable;

    NSWindow *newWindow = [[NSWindow alloc] initWithContentRect:frame
                                                      styleMask:style
                                                        backing:NSBackingStoreBuffered
                                                          defer:NO];
    [newWindow setTitle:[NSString stringWithUTF8String:title]];
    [newWindow setMinSize:NSMakeSize(200, 100)];
    [newWindow setTabbingMode:NSWindowTabbingModePreferred];

    VTTerminalView *view = [[VTTerminalView alloc] initWithFrame:frame];
    [newWindow setContentView:view];

    // Add as a tabbed window to the first window
    [vt_g_window addTabbedWindow:newWindow ordered:NSWindowAbove];
    [newWindow makeKeyAndOrderFront:nil];
    [newWindow makeFirstResponder:view];

    return (__bridge void*)view;
}

void vt_close_tab(void *view_ptr) {
    if (!view_ptr) return;
    VTTerminalView *view = (__bridge VTTerminalView *)view_ptr;
    NSWindow *window = [view window];
    if (window) {
        // Defer close to avoid reentrancy: this is often called from
        // within keyDown: event processing, and closing a tabbed window
        // synchronously from an event handler can deadlock AppKit.
        dispatch_async(dispatch_get_main_queue(), ^{
            [window close];
        });
    }
}

void vt_select_tab(int offset) {
    NSWindow *keyWindow = [NSApp keyWindow];
    if (!keyWindow) return;
    if (offset > 0) {
        [keyWindow selectNextTab:nil];
    } else if (offset < 0) {
        [keyWindow selectPreviousTab:nil];
    }
}

// ============================================================
// Display & sizing
// ============================================================

void vt_request_display(void *view_ptr) {
    if (!view_ptr) return;
    VTTerminalView *view = (__bridge VTTerminalView *)view_ptr;
    dispatch_async(dispatch_get_main_queue(), ^{
        [view setNeedsDisplay:YES];
    });
}

double vt_view_width(void *view_ptr) {
    if (!view_ptr) return 0;
    VTTerminalView *view = (__bridge VTTerminalView *)view_ptr;
    return [view bounds].size.width;
}

double vt_view_height(void *view_ptr) {
    if (!view_ptr) return 0;
    VTTerminalView *view = (__bridge VTTerminalView *)view_ptr;
    return [view bounds].size.height;
}

int vt_tab_count(void) {
    NSWindow *keyWindow = [NSApp keyWindow];
    if (!keyWindow) return 1;
    NSArray *tabs = [keyWindow tabbedWindows];
    if (!tabs) return 1;
    return (int)[tabs count];
}

// ============================================================
// Font / text drawing helpers
// ============================================================

const void* vt_ct_font_attribute_name(void) {
    return kCTFontAttributeName;
}

const void* vt_cf_allocator_null(void) {
    return kCFAllocatorNull;
}

const void* vt_cf_type_dictionary_key_callbacks(void) {
    return &kCFTypeDictionaryKeyCallBacks;
}

const void* vt_cf_type_dictionary_value_callbacks(void) {
    return &kCFTypeDictionaryValueCallBacks;
}

const void* vt_cf_type_array_callbacks(void) {
    return &kCFTypeArrayCallBacks;
}

void* vt_cf_character_set_create_with_range(long location, long length) {
    CFRange range = CFRangeMake(location, length);
    return (void*)CFCharacterSetCreateWithCharactersInRange(NULL, range);
}

const void* vt_k_ct_font_open_type_feature_tag(void) {
    return kCTFontOpenTypeFeatureTag;
}

const void* vt_k_ct_font_open_type_feature_value(void) {
    return kCTFontOpenTypeFeatureValue;
}

const void* vt_k_ct_font_feature_settings_attribute(void) {
    return kCTFontFeatureSettingsAttribute;
}

const void* vt_k_ct_typesetter_option_forced_embedding_level(void) {
    return kCTTypesetterOptionForcedEmbeddingLevel;
}

const void* vt_k_ct_paragraph_style_attribute_name(void) {
    return kCTParagraphStyleAttributeName;
}

const void* vt_k_ct_writing_direction_attribute_name(void) {
    return kCTWritingDirectionAttributeName;
}

void vt_cfattributedstring_replace_string(void *str_ptr, long location, long length, void *replacement_ptr) {
    if (!str_ptr || !replacement_ptr) return;
    CFAttributedStringReplaceString(
        (CFMutableAttributedStringRef)str_ptr,
        CFRangeMake(location, length),
        (CFStringRef)replacement_ptr
    );
}

void vt_cfattributedstring_set_attribute(void *str_ptr, long location, long length, void *key_ptr, void *value_ptr) {
    if (!str_ptr || !key_ptr) return;
    CFAttributedStringSetAttribute(
        (CFMutableAttributedStringRef)str_ptr,
        CFRangeMake(location, length),
        (CFStringRef)key_ptr,
        (CFTypeRef)value_ptr
    );
}

void* vt_create_font(const char *name, double size) {
    NSString *fontName = [NSString stringWithUTF8String:name];
    CTFontRef font = CTFontCreateWithName((__bridge CFStringRef)fontName, size, NULL);
    return (void*)font;
}

void vt_draw_text(CGContextRef ctx, const char *text, int text_len,
                  void *font, double x, double y,
                  double fg_r, double fg_g, double fg_b) {
    if (!text || text_len <= 0 || !font) return;

    CFStringRef cfstr = CFStringCreateWithBytes(
        NULL, (const UInt8*)text, text_len,
        kCFStringEncodingUTF8, false);
    if (!cfstr) return;

    CGColorRef color = CGColorCreateSRGB(fg_r, fg_g, fg_b, 1.0);

    CFStringRef keys[] = { kCTFontAttributeName, kCTForegroundColorAttributeName };
    CFTypeRef vals[] = { (CTFontRef)font, color };
    CFDictionaryRef attrs = CFDictionaryCreate(
        NULL, (const void**)keys, (const void**)vals, 2,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

    CFAttributedStringRef attrStr = CFAttributedStringCreate(NULL, cfstr, attrs);
    CTLineRef line = CTLineCreateWithAttributedString(attrStr);

    CGContextSetTextPosition(ctx, x, y);
    CTLineDraw(line, ctx);

    CFRelease(line);
    CFRelease(attrStr);
    CFRelease(attrs);
    CGColorRelease(color);
    CFRelease(cfstr);
}

// ============================================================
// CoreText helpers for V wrappers
// ============================================================

void* vt_ct_typesetter_create_line(void *typesetter_ptr, long location, long length) {
    if (!typesetter_ptr) return NULL;
    CFRange range = CFRangeMake(location, length);
    return (void*)CTTypesetterCreateLine((CTTypesetterRef)typesetter_ptr, range);
}

void vt_ctrun_get_glyphs_all(void *run_ptr, void *out_glyphs) {
    if (!run_ptr || !out_glyphs) return;
    CTRunGetGlyphs((CTRunRef)run_ptr, CFRangeMake(0, 0), (CGGlyph *)out_glyphs);
}

void vt_ctrun_get_advances_all(void *run_ptr, void *out_advances) {
    if (!run_ptr || !out_advances) return;
    CTRunGetAdvances((CTRunRef)run_ptr, CFRangeMake(0, 0), (CGSize *)out_advances);
}

void vt_ctrun_get_positions_all(void *run_ptr, void *out_positions) {
    if (!run_ptr || !out_positions) return;
    CTRunGetPositions((CTRunRef)run_ptr, CFRangeMake(0, 0), (CGPoint *)out_positions);
}

void vt_ctrun_get_string_indices_all(void *run_ptr, void *out_indices) {
    if (!run_ptr || !out_indices) return;
    CTRunGetStringIndices((CTRunRef)run_ptr, CFRangeMake(0, 0), (CFIndex *)out_indices);
}

void* vt_ctparagraphstyle_create(void *settings_ptr, size_t count) {
    return (void*)CTParagraphStyleCreate((const CTParagraphStyleSetting *)settings_ptr, count);
}

void* vt_ctframesetter_create_frame(void *framesetter_ptr, long location, long length, void *path_ptr, void *attrs_ptr) {
    if (!framesetter_ptr || !path_ptr) return NULL;
    return (void*)CTFramesetterCreateFrame(
        (CTFramesetterRef)framesetter_ptr,
        CFRangeMake(location, length),
        (CGPathRef)path_ptr,
        (CFDictionaryRef)attrs_ptr
    );
}

void vt_ctframe_get_line_origins(void *frame_ptr, long location, long length, void *points_ptr) {
    if (!frame_ptr || !points_ptr) return;
    CTFrameGetLineOrigins((CTFrameRef)frame_ptr, CFRangeMake(location, length), (CGPoint *)points_ptr);
}

// ============================================================
// CoreGraphics helpers for V wrappers
// ============================================================

bool vt_cgrect_is_null(double x, double y, double w, double h) {
    return CGRectIsNull(CGRectMake(x, y, w, h));
}

void* vt_cgpath_create_with_rect(double x, double y, double w, double h) {
    return (void*)CGPathCreateWithRect(CGRectMake(x, y, w, h), NULL);
}

void* vt_cgpath_create_mutable(void) {
    return (void*)CGPathCreateMutable();
}

void vt_cgpath_add_rect(void *path_ptr, double x, double y, double w, double h) {
    if (!path_ptr) return;
    CGPathAddRect((CGMutablePathRef)path_ptr, NULL, CGRectMake(x, y, w, h));
}

void vt_cgpath_get_bounding_box(void *path_ptr, double *x, double *y, double *w, double *h) {
    if (!path_ptr || !x || !y || !w || !h) return;
    CGRect rect = CGPathGetBoundingBox((CGPathRef)path_ptr);
    *x = rect.origin.x;
    *y = rect.origin.y;
    *w = rect.size.width;
    *h = rect.size.height;
}

void* vt_cgcolorspace_create_device_gray(void) {
    return (void*)CGColorSpaceCreateDeviceGray();
}

void* vt_cgcolorspace_create_device_rgb(void) {
    return (void*)CGColorSpaceCreateDeviceRGB();
}

void* vt_cgcolorspace_create_named(int name_id) {
    CFStringRef name = NULL;
    switch (name_id) {
        case 0: name = kCGColorSpaceDisplayP3; break;
        case 1: name = kCGColorSpaceExtendedLinearDisplayP3; break;
        case 2: name = kCGColorSpaceSRGB; break;
        case 3: name = kCGColorSpaceLinearSRGB; break;
        case 4: name = kCGColorSpaceExtendedSRGB; break;
        case 5: name = kCGColorSpaceExtendedLinearSRGB; break;
        case 6: name = kCGColorSpaceGenericGrayGamma2_2; break;
        case 7: name = kCGColorSpaceLinearGray; break;
        case 8: name = kCGColorSpaceExtendedGray; break;
        case 9: name = kCGColorSpaceExtendedLinearGray; break;
        default: return NULL;
    }
    return (void*)CGColorSpaceCreateWithName(name);
}

void vt_cgcolorspace_release(void *space_ptr) {
    if (!space_ptr) return;
    CGColorSpaceRelease((CGColorSpaceRef)space_ptr);
}

void* vt_cgbitmap_context_create(void *data, size_t width, size_t height,
                                 size_t bits_per_component, size_t bytes_per_row,
                                 void *space, unsigned int opts) {
    return (void*)CGBitmapContextCreate(
        data,
        width,
        height,
        bits_per_component,
        bytes_per_row,
        (CGColorSpaceRef)space,
        opts
    );
}

void vt_cgcontext_set_text_matrix(void *ctx_ptr, double a, double b, double c, double d, double tx, double ty) {
    if (!ctx_ptr) return;
    CGContextSetTextMatrix((CGContextRef)ctx_ptr, CGAffineTransformMake(a, b, c, d, tx, ty));
}

void vt_cgcontext_fill_rect(void *ctx_ptr, double x, double y, double w, double h) {
    if (!ctx_ptr) return;
    CGContextFillRect((CGContextRef)ctx_ptr, CGRectMake(x, y, w, h));
}

// ============================================================
// IOSurface helpers for V wrappers
// ============================================================

void* vt_iosurface_create(int width, int height, unsigned int pixel_format, int bytes_per_element, void *colorspace_ptr) {
    CFNumberRef w = CFNumberCreate(NULL, kCFNumberIntType, &width);
    CFNumberRef h = CFNumberCreate(NULL, kCFNumberIntType, &height);
    CFNumberRef pf = CFNumberCreate(NULL, kCFNumberIntType, &pixel_format);
    CFNumberRef bpe = CFNumberCreate(NULL, kCFNumberIntType, &bytes_per_element);
    if (!w || !h || !pf || !bpe) {
        if (w) CFRelease(w);
        if (h) CFRelease(h);
        if (pf) CFRelease(pf);
        if (bpe) CFRelease(bpe);
        return NULL;
    }

    const void *keys[] = {
        kIOSurfaceWidth,
        kIOSurfaceHeight,
        kIOSurfacePixelFormat,
        kIOSurfaceBytesPerElement,
    };
    const void *vals[] = { w, h, pf, bpe };
    CFDictionaryRef dict = CFDictionaryCreate(
        NULL,
        keys,
        vals,
        4,
        &kCFTypeDictionaryKeyCallBacks,
        &kCFTypeDictionaryValueCallBacks
    );

    CFRelease(w);
    CFRelease(h);
    CFRelease(pf);
    CFRelease(bpe);

    if (!dict) return NULL;
    IOSurfaceRef surface = IOSurfaceCreate(dict);
    CFRelease(dict);
    if (!surface) return NULL;

    if (colorspace_ptr) {
        CFPropertyListRef serialized = CGColorSpaceCopyPropertyList((CGColorSpaceRef)colorspace_ptr);
        if (serialized) {
            IOSurfaceSetValue(surface, kIOSurfaceColorSpace, serialized);
            CFRelease(serialized);
        }
    }

    return (void*)surface;
}

void vt_iosurface_deinit(void *surface_ptr) {
    if (!surface_ptr) return;
    IOSurfaceRef surface = (IOSurfaceRef)surface_ptr;
    IOSurfaceSetPurgeable(surface, kIOSurfacePurgeableEmpty, NULL);
    CFRelease(surface);
}

void vt_iosurface_retain(void *surface_ptr) {
    if (!surface_ptr) return;
    CFRetain(surface_ptr);
}

void vt_iosurface_release(void *surface_ptr) {
    if (!surface_ptr) return;
    CFRelease(surface_ptr);
}

void vt_iosurface_set_color_space(void *surface_ptr, void *colorspace_ptr) {
    if (!surface_ptr || !colorspace_ptr) return;
    CFPropertyListRef serialized = CGColorSpaceCopyPropertyList((CGColorSpaceRef)colorspace_ptr);
    if (!serialized) return;
    IOSurfaceSetValue((IOSurfaceRef)surface_ptr, kIOSurfaceColorSpace, serialized);
    CFRelease(serialized);
}

void vt_iosurface_lock(void *surface_ptr) {
    if (!surface_ptr) return;
    IOSurfaceLock((IOSurfaceRef)surface_ptr, 0, NULL);
}

void vt_iosurface_unlock(void *surface_ptr) {
    if (!surface_ptr) return;
    IOSurfaceUnlock((IOSurfaceRef)surface_ptr, 0, NULL);
}

size_t vt_iosurface_get_alloc_size(void *surface_ptr) {
    if (!surface_ptr) return 0;
    return IOSurfaceGetAllocSize((IOSurfaceRef)surface_ptr);
}

size_t vt_iosurface_get_width(void *surface_ptr) {
    if (!surface_ptr) return 0;
    return IOSurfaceGetWidth((IOSurfaceRef)surface_ptr);
}

size_t vt_iosurface_get_height(void *surface_ptr) {
    if (!surface_ptr) return 0;
    return IOSurfaceGetHeight((IOSurfaceRef)surface_ptr);
}

size_t vt_iosurface_get_bytes_per_element(void *surface_ptr) {
    if (!surface_ptr) return 0;
    return IOSurfaceGetBytesPerElement((IOSurfaceRef)surface_ptr);
}

size_t vt_iosurface_get_bytes_per_row(void *surface_ptr) {
    if (!surface_ptr) return 0;
    return IOSurfaceGetBytesPerRow((IOSurfaceRef)surface_ptr);
}

void* vt_iosurface_get_base_address(void *surface_ptr) {
    if (!surface_ptr) return NULL;
    return IOSurfaceGetBaseAddress((IOSurfaceRef)surface_ptr);
}

size_t vt_iosurface_get_element_width(void *surface_ptr) {
    if (!surface_ptr) return 0;
    return IOSurfaceGetElementWidth((IOSurfaceRef)surface_ptr);
}

size_t vt_iosurface_get_element_height(void *surface_ptr) {
    if (!surface_ptr) return 0;
    return IOSurfaceGetElementHeight((IOSurfaceRef)surface_ptr);
}

unsigned int vt_iosurface_get_pixel_format(void *surface_ptr) {
    if (!surface_ptr) return 0;
    return IOSurfaceGetPixelFormat((IOSurfaceRef)surface_ptr);
}

// ============================================================
// dispatch helpers for V wrappers
// ============================================================

void* vt_dispatch_get_main_queue(void) {
    return (void*)dispatch_get_main_queue();
}

void* vt_dispatch_data_create(const void *data, size_t len, void *queue) {
    return (void*)dispatch_data_create(data, len, (dispatch_queue_t)queue, NULL);
}

void vt_dispatch_release(void *obj) {
    if (!obj) return;
    dispatch_release((dispatch_object_t)obj);
}

// ============================================================
// CoreAnimation helpers for V wrappers
// ============================================================

const void* vt_kca_gravity_top_left(void) {
    return kCAGravityTopLeft;
}

const void* vt_kca_gravity_bottom_left(void) {
    return kCAGravityBottomLeft;
}

const void* vt_kca_gravity_center(void) {
    return kCAGravityCenter;
}

// ============================================================
// CoreVideo DisplayLink helpers for V wrappers
// ============================================================

void* vt_display_link_create_with_active_displays(void) {
    CVDisplayLinkRef link = NULL;
    if (CVDisplayLinkCreateWithActiveCGDisplays(&link) != kCVReturnSuccess) return NULL;
    return (void*)link;
}

void vt_display_link_release(void *link_ptr) {
    if (!link_ptr) return;
    CVDisplayLinkRelease((CVDisplayLinkRef)link_ptr);
}

bool vt_display_link_start(void *link_ptr) {
    if (!link_ptr) return false;
    return CVDisplayLinkStart((CVDisplayLinkRef)link_ptr) == kCVReturnSuccess;
}

bool vt_display_link_stop(void *link_ptr) {
    if (!link_ptr) return false;
    return CVDisplayLinkStop((CVDisplayLinkRef)link_ptr) == kCVReturnSuccess;
}

bool vt_display_link_is_running(void *link_ptr) {
    if (!link_ptr) return false;
    return CVDisplayLinkIsRunning((CVDisplayLinkRef)link_ptr) != 0;
}

bool vt_display_link_set_current_display(void *link_ptr, unsigned int display_id) {
    if (!link_ptr) return false;
    return CVDisplayLinkSetCurrentCGDisplay((CVDisplayLinkRef)link_ptr, display_id) == kCVReturnSuccess;
}

// ============================================================
// os/log helpers for V wrappers
// ============================================================

void* vt_os_log_create(const char *subsystem, const char *category) {
    return (void*)os_log_create(subsystem, category);
}

void vt_os_release(void *obj) {
    if (!obj) return;
    os_release(obj);
}

bool vt_os_log_type_enabled(void *log_ptr, unsigned char typ) {
    if (!log_ptr) return false;
    return os_log_type_enabled((os_log_t)log_ptr, (os_log_type_t)typ);
}

void vt_os_log_with_type_str(void *log_ptr, unsigned char typ, const char *msg) {
    if (!log_ptr || !msg) return;
    os_log_with_type((os_log_t)log_ptr, (os_log_type_t)typ, "%{public}s", msg);
}

// ============================================================
// os/signpost helpers for V wrappers
// ============================================================

bool vt_os_signpost_enabled(void *log_ptr) {
    if (!log_ptr) return false;
    return os_signpost_enabled((os_log_t)log_ptr);
}

unsigned long long vt_os_signpost_id_generate(void *log_ptr) {
    if (!log_ptr) return 0;
    return (unsigned long long)os_signpost_id_generate((os_log_t)log_ptr);
}

unsigned long long vt_os_signpost_id_for_pointer(void *log_ptr, void *ptr) {
    if (!log_ptr) return 0;
    return (unsigned long long)os_signpost_id_make_with_pointer((os_log_t)log_ptr, ptr);
}

static void vt_os_signpost_emit_with_name(void *log_ptr, unsigned long long id, const char *name, unsigned char typ) {
    if (!log_ptr || !name) return;
    uint8_t buf[2] = {0, 0};
    _os_signpost_emit_with_name_impl(
        &__dso_handle,
        (os_log_t)log_ptr,
        (os_signpost_type_t)typ,
        (os_signpost_id_t)id,
        name,
        "",
        buf,
        (uint32_t)sizeof(buf)
    );
}

void vt_os_signpost_event_emit(void *log_ptr, unsigned long long id, const char *name) {
    vt_os_signpost_emit_with_name(log_ptr, id, name, 0);
}

void vt_os_signpost_interval_begin(void *log_ptr, unsigned long long id, const char *name) {
    vt_os_signpost_emit_with_name(log_ptr, id, name, 1);
}

void vt_os_signpost_interval_end(void *log_ptr, unsigned long long id, const char *name) {
    vt_os_signpost_emit_with_name(log_ptr, id, name, 2);
}

// ============================================================
// Metal helpers — called from V
// ============================================================

// Activate the Metal layer as the view's backing layer.
// After this call, drawRect: will no longer use CGContext — all
// rendering must go through Metal command buffers.
void vt_metal_activate_layer(void *view_ptr) {
    if (!view_ptr) return;
    VTTerminalView *view = (__bridge VTTerminalView *)view_ptr;
    CAMetalLayer *layer = [view metalLayer];
    if (layer) {
        [view setWantsLayer:YES];
        [view setLayer:layer];
        NSSize size = [view bounds].size;
        CGFloat scale = layer.contentsScale;
        layer.drawableSize = CGSizeMake(size.width * scale, size.height * scale);
    }
}

// Get the Metal device from a view.
void* vt_metal_device(void *view_ptr) {
    if (!view_ptr) return NULL;
    VTTerminalView *view = (__bridge VTTerminalView *)view_ptr;
    return (__bridge void*)[view metalDevice];
}

// Get the Metal command queue from a view.
void* vt_metal_queue(void *view_ptr) {
    if (!view_ptr) return NULL;
    VTTerminalView *view = (__bridge VTTerminalView *)view_ptr;
    return (__bridge void*)[view metalQueue];
}

// Get the Metal layer from a view.
void* vt_metal_layer(void *view_ptr) {
    if (!view_ptr) return NULL;
    VTTerminalView *view = (__bridge VTTerminalView *)view_ptr;
    return (__bridge void*)[view metalLayer];
}

// Get the next drawable from the Metal layer.
void* vt_metal_next_drawable(void *layer_ptr) {
    if (!layer_ptr) return NULL;
    CAMetalLayer *layer = (__bridge CAMetalLayer *)layer_ptr;
    id<CAMetalDrawable> drawable = [layer nextDrawable];
    return (__bridge_retained void*)drawable;
}

// Get the texture from a drawable.
void* vt_metal_drawable_texture(void *drawable_ptr) {
    if (!drawable_ptr) return NULL;
    id<CAMetalDrawable> drawable = (__bridge id<CAMetalDrawable>)drawable_ptr;
    return (__bridge void*)[drawable texture];
}

// Create a command buffer from the queue.
void* vt_metal_create_command_buffer(void *queue_ptr) {
    if (!queue_ptr) return NULL;
    id<MTLCommandQueue> queue = (__bridge id<MTLCommandQueue>)queue_ptr;
    id<MTLCommandBuffer> buffer = [queue commandBuffer];
    return (__bridge_retained void*)buffer;
}

// Create a render pass descriptor with a clear color.
void* vt_metal_create_render_pass(void *texture_ptr, double r, double g, double b, double a) {
    if (!texture_ptr) return NULL;
    id<MTLTexture> texture = (__bridge id<MTLTexture>)texture_ptr;
    MTLRenderPassDescriptor *desc = [MTLRenderPassDescriptor renderPassDescriptor];
    desc.colorAttachments[0].texture = texture;
    desc.colorAttachments[0].loadAction = MTLLoadActionClear;
    desc.colorAttachments[0].storeAction = MTLStoreActionStore;
    desc.colorAttachments[0].clearColor = MTLClearColorMake(r, g, b, a);
    return (__bridge_retained void*)desc;
}

// Create a render command encoder from a command buffer + render pass descriptor.
void* vt_metal_create_encoder(void *cmd_buf_ptr, void *pass_ptr) {
    if (!cmd_buf_ptr || !pass_ptr) return NULL;
    id<MTLCommandBuffer> cmdBuf = (__bridge id<MTLCommandBuffer>)cmd_buf_ptr;
    MTLRenderPassDescriptor *pass = (__bridge MTLRenderPassDescriptor *)pass_ptr;
    id<MTLRenderCommandEncoder> encoder = [cmdBuf renderCommandEncoderWithDescriptor:pass];
    return (__bridge_retained void*)encoder;
}

// End encoding on a render command encoder.
void vt_metal_end_encoding(void *encoder_ptr) {
    if (!encoder_ptr) return;
    id<MTLRenderCommandEncoder> encoder = (__bridge_transfer id<MTLRenderCommandEncoder>)encoder_ptr;
    [encoder endEncoding];
}

// Present the drawable and commit the command buffer.
void vt_metal_present_and_commit(void *cmd_buf_ptr, void *drawable_ptr) {
    if (!cmd_buf_ptr || !drawable_ptr) return;
    id<MTLCommandBuffer> cmdBuf = (__bridge_transfer id<MTLCommandBuffer>)cmd_buf_ptr;
    id<CAMetalDrawable> drawable = (__bridge_transfer id<CAMetalDrawable>)drawable_ptr;
    [cmdBuf presentDrawable:drawable];
    [cmdBuf commit];
}

// Release a bridged-retained pointer (drawable, command buffer, etc.)
void vt_metal_release(void *ptr) {
    if (!ptr) return;
    CFRelease(ptr);
}

// Get the maximum texture size supported by the device.
unsigned int vt_metal_max_texture_size(void *device_ptr) {
    if (!device_ptr) return 16384;
    id<MTLDevice> device = (__bridge id<MTLDevice>)device_ptr;
    if ([device supportsFamily:MTLGPUFamilyApple3]) {
        return 16384;
    }
    return 8192;
}

// Check if the device has unified memory (Apple Silicon).
bool vt_metal_has_unified_memory(void *device_ptr) {
    if (!device_ptr) return true;
    id<MTLDevice> device = (__bridge id<MTLDevice>)device_ptr;
    return [device hasUnifiedMemory];
}
