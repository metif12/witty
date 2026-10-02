#include <AppKit/AppKit.h>

static inline void witty_macos_observe_application_appearance(void* observer) {
    [NSApp addObserver:(id)observer forKeyPath:@"effectiveAppearance"
               options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial
               context:NULL];
}
static inline void witty_macos_remove_application_appearance_observer(void* observer) {
    [NSApp removeObserver:(id)observer forKeyPath:@"effectiveAppearance"];
}
