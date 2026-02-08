// appkit.m — Objective-C helpers for vterminal's macOS window.
// Compiled automatically by V via #include in appkit.v.

#import <AppKit/AppKit.h>
#import <CoreText/CoreText.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>

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
