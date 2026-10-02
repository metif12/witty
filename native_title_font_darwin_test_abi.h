#include <AppKit/AppKit.h>

static inline bool witty_title_font_matches(void* view, const char* family) {
    NSWindow* window = [(NSView*)view window];
    NSAttributedString* title = window.tab.attributedTitle;
    if (!family) return title == nil;
    if (title.length == 0) return false;
    NSFont* font = [title attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
    return [font isEqual:[NSFont fontWithName:[NSString stringWithUTF8String:family]
                                       size:NSFont.systemFontSize]];
}
static inline bool witty_title_font_title(void* view, const char* title) {
    NSWindow* window = [(NSView*)view window];
    NSString* expected = [NSString stringWithUTF8String:title];
    window.title = expected;
    return [window.tab.attributedTitle.string isEqualToString:expected];
}
