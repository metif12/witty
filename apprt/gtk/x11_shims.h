#pragma once

#include <X11/XKBlib.h>
#include <X11/Xlib.h>

static inline int witty_x11_event_type(const void *event) {
  return ((const XEvent *)event)->type;
}

static inline int witty_xkb_event_type(const void *event) {
  return ((const XkbEvent *)event)->any.xkb_type;
}

static inline unsigned int witty_xkb_event_lookup_mods(const void *event) {
  return ((const XkbEvent *)event)->state.lookup_mods;
}
