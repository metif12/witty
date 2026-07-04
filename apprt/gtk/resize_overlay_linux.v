module gtk

// resize_overlay_linux.v - The GObject ResizeOverlay widget class for the GTK
// apprt.
//
// Translated from ghostty/src/apprt/gtk/class/resize_overlay.zig.
//
// The overlay shows the current terminal size while a surface is resizing. It
// is a small `adw.Bin` subclass wrapping a `gtk.Label`, plus three glib
// timeout/idle sources that drive the show/hide behavior:
//
//   1. `first_delay` (delay_timer): a startup delay before ANY overlay is shown.
//   2. `idler`: coalesces schedule() calls onto the next GTK idle tick so we
//      don't flicker while GTK is busy rearranging widgets mid-resize.
//   3. `duration` (timer): how long the overlay stays visible before hiding.
//
// FOLLOWING THE ESTABLISHED PATTERN (surface_class_linux.v etc.): the GObject
// registration, `.ui`/blueprint template, and property machinery are stubbed
// with `// TODO(gtk)`; the real timer/idle state-machine logic is translated.
// The class is modeled as a plain V struct wrapping the GObject/GtkWidget ptr.

// --- New C bindings unique to this file -----------------------------------
//
// GtkLabel + a couple of GtkWidget helpers not declared elsewhere in the
// module. All opaque handles reuse the module's `voidptr` alias convention. We
// grep-checked that none of these `fn C.` decls already exist.

// GtkLabel*.
pub type GtkLabel = voidptr

fn C.gtk_label_set_label(label GtkLabel, str &char)

// --- gtk.Align ------------------------------------------------------------

// Align mirrors gtk.Align. Declared here (the first overlay file that needs
// it); search_overlay_linux.v / key_state_overlay_linux.v reuse it.
pub enum Align {
	fill
	start
	end
	center
	baseline
}

// --- ResizeOverlay --------------------------------------------------------

// ResizeOverlay is the V model of the `GhosttyResizeOverlay` GObject class. It
// wraps the GObject/GtkWidget pointer and carries the fields that lived in the
// Zig `Private` struct. The GObject/template machinery is stubbed (see the
// class-registration TODO at the end).
@[heap]
pub struct ResizeOverlay {
pub mut:
	// The GtkWidget (adw.Bin) pointer for this instance.
	widget GtkWidget = unsafe { nil }

	// The label with the text (template child).
	label GtkLabel = unsafe { nil }

	// The text to set on the label when scheduled. `none` means "hide".
	label_text ?string

	// The time (ms) that the overlay stays visible once shown.
	duration u32 = 750

	// The first delay (ms) before any overlay is shown. Must be specified during
	// construction otherwise it has no effect.
	first_delay u32 = 250

	// The idle source id used to update the label. 0 means "no source".
	idler u32

	// The timer source id for dismissing the overlay. 0 means "no timer".
	timer u32

	// The first-delay timer source id. 0 means "no timer".
	delay_timer u32

	// The alignment of the overlay within its parent.
	halign Align = .center
	valign Align = .center
}

// new_resize_overlay creates a new ResizeOverlay. Mirrors instance `init`:
// initializes the template and arms the first-delay timer if configured.
pub fn new_resize_overlay() &ResizeOverlay {
	mut self := &ResizeOverlay{}
	// TODO(gtk): gtk.Widget.initTemplate(self.as(gtk.Widget)).
	if self.first_delay > 0 {
		// TODO(gtk): delay_timer = glib.timeoutAdd(first_delay, onDelayTimer, self).
		self.delay_timer = C.g_timeout_add(self.first_delay, on_resize_delay_timer, self)
	}
	return self
}

// set_label sets the overlay label text. This does NOT show the overlay if it
// is currently hidden; callers must call `schedule`. Mirrors `setLabel`.
pub fn (mut self ResizeOverlay) set_label(label ?string) {
	self.label_text = label
	// TODO(gtk): notifyByPspec(properties.label).
}

// schedule schedules the overlay to be shown on the next idle tick. To avoid
// flickering during resizes we defer the actual show to when GTK is idle.
// Mirrors `schedule`.
pub fn (mut self ResizeOverlay) schedule() {
	// If we have a delay timer then we're not showing anything yet, so do
	// nothing.
	if self.delay_timer != 0 {
		return
	}

	// Wait until GTK is "idle" before updating the widget; scheduling multiple
	// idle sources would be wasteful, so bail if one is already armed.
	if self.idler != 0 {
		return
	}
	// TODO(gtk): idler = glib.idleAdd(onIdle, self). glib.idleAdd isn't bound in
	// the module yet; we model it with a zero-delay timeout which fires on the
	// next main-loop iteration, matching the coalescing semantics.
	self.idler = C.g_timeout_add(0, on_resize_idle, self)
}

// on_idle is the idle callback that actually shows/hides the overlay. Mirrors
// `onIdle`. Returns 0 (G_SOURCE_REMOVE) as in the Zig original.
fn (mut self ResizeOverlay) on_idle() int {
	// No matter what, our idler is complete with this callback.
	self.idler = 0

	// Cancel our previous show timer no matter what.
	if self.timer != 0 {
		C.g_source_remove(self.timer)
		self.timer = 0
	}

	// If we have a label to show, show ourselves. Otherwise hide.
	text := self.label_text or {
		C.gtk_widget_set_visible(self.widget, false)
		return 0
	}

	// Set our label and show it.
	C.gtk_label_set_label(self.label, text.str)
	C.gtk_widget_set_visible(self.widget, true)

	// Setup the new timer to hide ourselves after the duration.
	self.timer = C.g_timeout_add(self.duration, on_resize_timer, self)

	return 0
}

// on_timer hides the overlay when the display duration elapses. Mirrors
// `onTimer`.
fn (mut self ResizeOverlay) on_timer() int {
	self.timer = 0
	C.gtk_widget_set_visible(self.widget, false)
	return 0
}

// on_delay_timer clears the first-delay timer once it elapses. Mirrors
// `onDelayTimer`.
fn (mut self ResizeOverlay) on_delay_timer() int {
	self.delay_timer = 0
	return 0
}

// dispose removes any pending sources. Mirrors the `dispose` virtual method.
pub fn (mut self ResizeOverlay) dispose() {
	if self.idler != 0 {
		C.g_source_remove(self.idler)
		self.idler = 0
	}
	if self.timer != 0 {
		C.g_source_remove(self.timer)
		self.timer = 0
	}
	if self.delay_timer != 0 {
		C.g_source_remove(self.delay_timer)
		self.delay_timer = 0
	}
	// TODO(gtk): gtk.Widget.disposeTemplate + chain up to parent dispose.
}

// --- C-ABI timeout/idle trampolines ---------------------------------------
// These are the plain-C callbacks that glib invokes. Each recovers `self` from
// the user-data pointer and forwards to the corresponding method.

fn on_resize_idle(ud voidptr) int {
	if isnil(ud) {
		return 0
	}
	mut self := unsafe { &ResizeOverlay(ud) }
	return self.on_idle()
}

fn on_resize_timer(ud voidptr) int {
	if isnil(ud) {
		return 0
	}
	mut self := unsafe { &ResizeOverlay(ud) }
	return self.on_timer()
}

fn on_resize_delay_timer(ud voidptr) int {
	if isnil(ud) {
		return 0
	}
	mut self := unsafe { &ResizeOverlay(ud) }
	return self.on_delay_timer()
}

// --- GObject class registration (stub) ------------------------------------
//
// TODO(gtk): In ghostty this class is registered via gobject.ext.defineClass
// with an instanceInit, classInit, and a Private struct. classInit loads the
// `resize-overlay` blueprint `.ui` template, binds the `label` template child,
// registers the `duration`/`first-delay`/`label`/`overlay-halign`/
// `overlay-valign` properties, and wires the dispose/finalize virtual methods.
// V has no such machinery, so all of that is stubbed; the timer/idle handlers
// above are plain methods instead of C template callbacks.
