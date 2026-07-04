module gtk

// surface_class_linux.v - The GObject Surface *widget* class for the GTK apprt.
//
// Translated from ghostty/src/apprt/gtk/class/surface.zig.
//
// This is the core GTK4 GObject widget that hosts the terminal: a GtkGLArea
// for rendering plus a set of input event controllers (key/mouse/scroll/focus)
// that build input events and forward them to the core surface. In ghostty
// this is a `GhosttySurface` GObject class defined with a `.ui`/blueprint
// template, GObject property/signal registration and template-child bindings.
//
// V has no GObject class-registration or `.ui`-template machinery, and this
// `gtk` submodule CANNOT import witty's root `module main` where the real core
// `Surface` lives. Therefore:
//
//   * The class is modeled as a plain V struct `SurfaceWidget` that wraps the
//     GObject/GtkWidget pointer and holds the fields that were in the Zig
//     `Private` struct. Methods are `pub fn` on that struct. (The name is
//     `SurfaceWidget`, not `Surface`, to avoid colliding with the apprt
//     adapter `Surface` in surface_linux.v.)
//   * GObject type registration, signal wiring, and `.ui`/blueprint templates
//     are STUBBED with `// TODO(gtk)` and minimal type-checking bodies.
//   * Calls into the core surface dispatch to the real `core.Surface` (see
//     core/surface.v). Signatures are kept faithful.
//
// What is genuinely TRANSLATED: the GLArea realize/unrealize/render/resize
// setup, the input event handlers (key press/release, mouse down/up/motion/
// leave, scroll vertical/horizontal), the input-method state machine, clipboard
// get/request/set structure, cursor/title/mouse-shape/focus handling, and the
// Gtk.Scrollable adjustment plumbing. Keyboard handling reuses witty's input
// types (input.Key / input.Mods) and key_linux.v (key_from_keyval /
// translate_mods).

import apprt
import core
import input
import terminal

// --- New C bindings unique to this file -----------------------------------
//
// GtkGLArea / GtkEventController* / GtkGesture* / GdkClipboard functions that
// aren't declared elsewhere in the module. All opaque handles are `voidptr`
// aliases (matching the module convention in c_gtk_linux.v). We grep-checked
// that none of these `fn C.` decls already exist in the module.

// GtkGLArea*.
pub type GtkGLArea = voidptr

// GtkEventControllerKey*.
pub type GtkEventControllerKey = voidptr

// GtkEventControllerMotion*.
pub type GtkEventControllerMotion = voidptr

// GtkEventControllerScroll*.
pub type GtkEventControllerScroll = voidptr

// GtkEventControllerFocus*.
pub type GtkEventControllerFocus = voidptr

// GtkGestureClick*.
pub type GtkGestureClick = voidptr

// GtkIMContext* / GtkIMMulticontext*.
pub type GtkIMContext = voidptr

// GdkClipboard*.
pub type GdkClipboard = voidptr

// GtkAdjustment*.
pub type GtkAdjustment = voidptr

// GtkGLArea
fn C.gtk_gl_area_queue_render(area GtkGLArea)
fn C.gtk_gl_area_make_current(area GtkGLArea)
fn C.gtk_gl_area_get_error(area GtkGLArea) GError

// GtkWidget (extra helpers not in c_gtk_linux.v)
fn C.gtk_widget_has_focus(widget GtkWidget) bool
fn C.gtk_widget_set_cursor_from_name(widget GtkWidget, name &char)
fn C.gtk_widget_set_visible(widget GtkWidget, visible bool)
fn C.gtk_widget_add_css_class(widget GtkWidget, css_class &char)
fn C.gtk_widget_remove_css_class(widget GtkWidget, css_class &char)
fn C.gtk_widget_get_clipboard(widget GtkWidget) GdkClipboard
fn C.gtk_widget_get_primary_clipboard(widget GtkWidget) GdkClipboard

// GtkIMContext
fn C.gtk_im_context_filter_keypress(context GtkIMContext, event GdkEvent) bool
fn C.gtk_im_context_focus_in(context GtkIMContext)
fn C.gtk_im_context_focus_out(context GtkIMContext)
fn C.gtk_im_context_reset(context GtkIMContext)
fn C.gtk_im_context_set_client_widget(context GtkIMContext, widget GtkWidget)

// GdkEvent
fn C.gdk_event_get_modifier_state(event GdkEvent) u32

// GdkClipboard
fn C.gdk_clipboard_set_text(clipboard GdkClipboard, text &char)

// --- IMKeyEvent -----------------------------------------------------------

// IMKeyEvent is the state of the key event while doing IM composition.
// See key_event for detailed descriptions. Mirrors the Zig `IMKeyEvent`.
pub enum IMKeyEvent {
	// Not in a key event.
	false_
	// In a key event but im_composing was either true or false prior to the
	// calling IME processing. This is important to work around different input
	// methods calling commit and preedit end in a different order.
	composing
	not_composing
}

// Size is the simple dimensions struct used by various properties.
// Mirrors the Zig boxed `Surface.Size`.
pub struct Size {
pub mut:
	width  u32
	height u32
}

// --- SurfaceWidget --------------------------------------------------------

// SurfaceWidget is the V model of the `GhosttySurface` GObject class. It wraps
// the GObject/GtkWidget pointer and carries the state that lived in the Zig
// `Private` struct. The GObject/template machinery it would normally register
// is stubbed (see the class-registration TODO block at the end).
@[heap]
pub struct SurfaceWidget {
pub mut:
	// The GtkWidget (adw.Bin) pointer for this instance. In ghostty this is the
	// GObject parent instance; here we just hold the widget handle.
	widget GtkWidget = unsafe { nil }

	// The GLArea that renders the actual surface (template child).
	gl_area GtkGLArea = unsafe { nil }

	// The input method context (template child).
	im_context GtkIMContext = unsafe { nil }

	// The core surface backing this GTK surface. This starts out nil because it
	// can't be initialized until there is a realized GLArea. In ghostty this is
	// `?*core.Surface`; we model "unset" with `unsafe { nil }`.
	core_surface &core.Surface = unsafe { nil }

	// The apprt Surface adapter (see surface_linux.v).
	rt_surface Surface

	// The configuration this surface uses (out of scope: config GObject).
	config &Config = unsafe { nil }

	// The cgroup created for this surface, if any.
	cgroup_path ?string

	// The default/min size for a window embedding this surface.
	default_size ?Size
	min_size     ?Size

	// The requested font size in points (only applies to initialization).
	// 0 means "unset". In ghostty this is `?*font.face.DesiredSize`.
	font_size_request f32

	// The mouse shape to show for the surface.
	mouse_shape terminal.MouseShape = .text

	// Whether the mouse should be hidden as requested externally.
	mouse_hidden bool

	// The URL that the mouse is currently hovering over.
	mouse_hover_url ?string

	// The current working directory (reported externally by shell integration).
	pwd ?string

	// The terminal-set title and manually overridden title.
	title          ?string
	title_override ?string

	// The current focus state.
	focused bool = true

	// Whether this surface is "zoomed" (takes full bounds of a split view).
	zoom bool

	// Cached metrics for libghostty callbacks.
	size       apprt.SurfaceSize
	cursor_pos apprt.CursorPos

	// Input method state. All related to key input.
	in_keyevent IMKeyEvent = .false_
	im_composing bool
	im_buf       []u8 = []u8{len: 128}
	im_len       int

	// True when we have a precision scroll in progress.
	precision_scroll bool

	// True when the child has exited.
	child_exited bool

	// True while the bell is ringing.
	bell_ringing bool

	// True if this surface is in an error state (terminal non-functional).
	error_state bool

	// True if the current surface is a split (for unfocused-split-* options).
	is_split bool

	// Whether primary paste (middle-click paste) is enabled.
	gtk_enable_primary_paste bool = true

	// Key state tracking for key sequences and tables.
	key_sequence []string
	key_tables   []string

	// Gtk.Scrollable interface adjustments.
	hadj GtkAdjustment = unsafe { nil }
	vadj GtkAdjustment = unsafe { nil }

	// How much pending horizontal scroll we have.
	pending_horizontal_scroll f64
}

// --- Basic accessors ------------------------------------------------------

// core returns the (optional) core surface. Mirrors `Surface.core`.
pub fn (self &SurfaceWidget) core() &core.Surface {
	return self.core_surface
}

// has_core reports whether the core surface has been initialized.
pub fn (self &SurfaceWidget) has_core() bool {
	return !isnil(self.core_surface)
}

// rt returns the apprt Surface adapter. Mirrors `Surface.rt`.
pub fn (mut self SurfaceWidget) rt() &Surface {
	return &self.rt_surface
}

// redraw forces the surface to redraw itself. Mirrors `Surface.redraw`.
pub fn (self &SurfaceWidget) redraw() {
	C.gtk_gl_area_queue_render(self.gl_area)
}

// as_widget returns the underlying GtkWidget. Mirrors `self.as(gtk.Widget)`.
fn (self &SurfaceWidget) as_widget() GtkWidget {
	return self.widget
}

// --- Focus ----------------------------------------------------------------

// grab_focus focuses the input (GLArea) part of the surface.
// Mirrors `Surface.grabFocus`.
pub fn (self &SurfaceWidget) grab_focus() {
	C.gtk_widget_grab_focus(self.gl_area)
}

// get_focused returns the focus state. Mirrors `Surface.getFocused`.
pub fn (self &SurfaceWidget) get_focused() bool {
	return self.focused
}

// --- Content scale / size / cursor ----------------------------------------

// get_content_scale returns the content scale for the surface. Mirrors
// `Surface.getContentScale`. The GTK scale factor and gtk-xft-dpi scaling are
// combined, matching the Zig original.
pub fn (self &SurfaceWidget) get_content_scale() !apprt.ContentScale {
	mut gtk_scale := f32(1.0)
	s := C.gtk_widget_get_scale_factor(self.gl_area)
	if s > 0 {
		gtk_scale = f32(s)
	}

	// Also scale using font-specific DPI (gtk-xft-dpi is font DPI * 1024).
	mut xft_dpi_scale := f32(1.0)
	if gtk_xft_dpi := gtk_setting_xft_dpi() {
		if gtk_xft_dpi > 0 {
			xft_dpi := f32(gtk_xft_dpi) / 1024.0
			xft_dpi_scale = xft_dpi / 96.0
		}
	}

	scale := gtk_scale * xft_dpi_scale
	return apprt.ContentScale{
		x: scale
		y: scale
	}
}

// get_size returns the cached surface size in pixels. Mirrors `Surface.getSize`.
pub fn (self &SurfaceWidget) get_size() !apprt.SurfaceSize {
	return self.size
}

// get_cursor_pos returns the cached cursor position. Mirrors
// `Surface.getCursorPos`.
pub fn (self &SurfaceWidget) get_cursor_pos() !apprt.CursorPos {
	return self.cursor_pos
}

// scaled_coordinates scales x/y by the GDK device scale factor. Mirrors
// `Surface.scaledCoordinates`.
fn (self &SurfaceWidget) scaled_coordinates(x f64, y f64) (f64, f64) {
	scale_factor := f64(C.gtk_widget_get_scale_factor(self.gl_area))
	return x * scale_factor, y * scale_factor
}

// --- Title / pwd ----------------------------------------------------------

// get_title returns the terminal-set title, if any. Mirrors `Surface.getTitle`.
pub fn (self &SurfaceWidget) get_title() ?string {
	return self.title
}

// set_title sets the terminal-set title (a copy). Mirrors `Surface.setTitle`.
pub fn (mut self SurfaceWidget) set_title(title ?string) {
	self.title = title
	// TODO(gtk): notifyByPspec(properties.title) — GObject property notify.
}

// set_title_override sets the manually overridden title. Mirrors
// `Surface.setTitleOverride`.
pub fn (mut self SurfaceWidget) set_title_override(title ?string) {
	self.title_override = title
	// TODO(gtk): notifyByPspec(properties.title-override).
}

// get_pwd returns the pwd, if any. Mirrors `Surface.getPwd`.
pub fn (self &SurfaceWidget) get_pwd() ?string {
	return self.pwd
}

// set_pwd sets the pwd (a copy). Mirrors `Surface.setPwd`.
pub fn (mut self SurfaceWidget) set_pwd(pwd ?string) {
	self.pwd = pwd
	// TODO(gtk): notifyByPspec(properties.pwd).
}

// --- Mouse shape / hidden / hover url --------------------------------------

// get_mouse_shape returns the mouse shape. Mirrors `Surface.getMouseShape`.
pub fn (self &SurfaceWidget) get_mouse_shape() terminal.MouseShape {
	return self.mouse_shape
}

// set_mouse_shape sets the mouse shape and applies it. Mirrors
// `Surface.setMouseShape` + `propMouseShape`.
pub fn (mut self SurfaceWidget) set_mouse_shape(shape terminal.MouseShape) {
	self.mouse_shape = shape
	self.apply_mouse_shape()
}

// get_mouse_hidden returns whether the mouse is hidden. Mirrors
// `Surface.getMouseHidden`.
pub fn (self &SurfaceWidget) get_mouse_hidden() bool {
	return self.mouse_hidden
}

// set_mouse_hidden sets whether the mouse is hidden and applies it. Mirrors
// `Surface.setMouseHidden` + `propMouseHidden`.
pub fn (mut self SurfaceWidget) set_mouse_hidden(hidden bool) {
	self.mouse_hidden = hidden
	if self.mouse_hidden {
		C.gtk_widget_set_cursor_from_name(self.widget, c'none')
		return
	}
	self.apply_mouse_shape()
}

// apply_mouse_shape sets the widget cursor from the current mouse shape.
// Mirrors the body of `propMouseShape`. Note: witty's terminal.MouseShape is a
// reduced enum (6 shapes) versus ghostty's 34, so only those cases exist.
fn (self &SurfaceWidget) apply_mouse_shape() {
	if self.mouse_hidden {
		return
	}
	name := match self.mouse_shape {
		.default_ { c'default' }
		.text { c'text' }
		.pointer { c'pointer' }
		.crosshair { c'crosshair' }
		.help { c'help' }
		.progress { c'progress' }
	}
	C.gtk_widget_set_cursor_from_name(self.widget, name)
}

// set_mouse_hover_url sets the hovered URL (a copy) and toggles the URL label.
// Mirrors `Surface.setMouseHoverUrl` + `propMouseHoverUrl`.
pub fn (mut self SurfaceWidget) set_mouse_hover_url(url ?string) {
	self.mouse_hover_url = url
	// TODO(gtk): toggle the url_left label visibility (template child).
}

// --- Bell / error ---------------------------------------------------------

// get_bell_ringing returns whether the bell is ringing. Mirrors
// `Surface.getBellRinging`.
pub fn (self &SurfaceWidget) get_bell_ringing() bool {
	return self.bell_ringing
}

// set_bell_ringing sets the bell ringing state. Mirrors `Surface.setBellRinging`.
pub fn (mut self SurfaceWidget) set_bell_ringing(ringing bool) {
	// Logic around bell reaction happens on every event even if we're already
	// ringing.
	if ringing {
		self.ring_bell()
	}

	// Property change only happens on actual state change.
	if self.bell_ringing == ringing {
		return
	}
	self.bell_ringing = ringing
	// TODO(gtk): notifyByPspec(properties.bell-ringing).
}

// ring_bell handles bell features that happen on every BEL (audio/system).
// Mirrors `Surface.ringBell` (audio playback and action activation are stubbed
// because they need the config GObject + GtkMediaFile machinery).
fn (self &SurfaceWidget) ring_bell() {
	// TODO(gtk): emit `bell` signal; activate tab.ring-bell / win.ring-bell;
	// play bell-audio via GtkMediaFile per config.@"bell-features".
}

// set_error sets the error state. Mirrors `Surface.setError`.
pub fn (mut self SurfaceWidget) set_error(v bool) {
	self.error_state = v
	if v {
		C.gtk_widget_add_css_class(self.widget, c'background')
	} else {
		C.gtk_widget_remove_css_class(self.widget, c'background')
	}
	// TODO(gtk): swap child between error_page and terminal_page on idle tick.
}

// --- Default / min size ----------------------------------------------------

// get_default_size returns the default size, if set. Mirrors
// `Surface.getDefaultSize`.
pub fn (self &SurfaceWidget) get_default_size() ?Size {
	return self.default_size
}

// set_default_size sets the default size. Mirrors `Surface.setDefaultSize`.
pub fn (mut self SurfaceWidget) set_default_size(size Size) {
	self.default_size = size
	// TODO(gtk): notifyByPspec(properties.default-size).
}

// get_min_size returns the min size, if set. Mirrors `Surface.getMinSize`.
pub fn (self &SurfaceWidget) get_min_size() ?Size {
	return self.min_size
}

// set_min_size sets the min size. Mirrors `Surface.setMinSize`.
pub fn (mut self SurfaceWidget) set_min_size(size Size) {
	self.min_size = size
	// TODO(gtk): notifyByPspec(properties.min-size).
}

// --- cgroup ---------------------------------------------------------------

// cgroup_path returns the cgroup path, if any. Mirrors `Surface.cgroupPath`.
pub fn (self &SurfaceWidget) cgroup_path() ?string {
	return self.cgroup_path
}

// --- Key input ------------------------------------------------------------

// core_key_action maps the apprt/input KeyAction to the core.KeyAction used by
// core.Surface.key_callback. The two enums have different member ordering so a
// numeric cast is not safe.
fn core_key_action(action input.KeyAction) core.KeyAction {
	return match action {
		.press { core.KeyAction.press }
		.repeat { core.KeyAction.repeat }
		.release { core.KeyAction.release }
	}
}

// key_event handles a key press or release. This is the meat of keyboard
// input handling. Faithfully translated from `Surface.keyEvent`:
//   * runs the GdkEvent through the input method context (for preedit/commit),
//   * maintains the in_keyevent / im_composing state machine,
//   * derives the physical key, modifiers, consumed modifiers and utf8 text,
//   * forwards an input.KeyEvent to the core surface via keyCallback.
//
// `event` is the current GdkEvent for the controller. Returns true if handled.
pub fn (mut self SurfaceWidget) key_event(action input.KeyAction, event GdkEvent, keyval u32, keycode u32, gtk_mods u32) bool {
	if isnil(event) {
		return false
	}

	// Input-method handling block. See the function comment.
	{
		// Notify the IM context where the cursor is so it can render dropdowns
		// in the right place.
		if self.has_core() {
			// TODO(gtk): set_cursor_location from core_surface.imePoint().
		}

		// Note that we're in a keypress; some logic depends on this (see the
		// commit handler). We track whether we were composing beforehand
		// because different input methods call callbacks in different orders.
		self.in_keyevent = if self.im_composing { IMKeyEvent.composing } else { IMKeyEvent.not_composing }

		// Pass the event through the input method. Returns true if handled.
		im_handled := C.gtk_im_context_filter_keypress(self.im_context, event)

		if im_handled {
			// If composing then we're in a preedit state and don't encode keys.
			if self.im_composing {
				self.in_keyevent = .false_
				return true
			}
			// If we WERE composing and now aren't, we committed text; don't
			// encode a key event for this either.
			if self.in_keyevent == .composing {
				self.in_keyevent = .false_
				return true
			}
			// Not composing and empty IM buffer: the IM reacted (e.g. opened an
			// onscreen keyboard) without giving us text, so don't encode.
			if self.im_len == 0 {
				self.in_keyevent = .false_
				return true
			}
		}
	}

	// Reset in_keyevent now that the IM block is done.
	self.in_keyevent = .false_

	// Get the unicode value for this keyval.
	keyval_cp := keyval_unicode(keyval)

	// We want the physical unmapped key to process physical keybinds.
	//
	// NOTE(gtk): ghostty looks up the physical key from the platform keycode via
	// input.keycodes (native == keycode). witty's keycodes table currently holds
	// macOS native codes, not Linux/XKB codes, so that lookup can't be done
	// faithfully here yet. We fall back to the keyval-based remapped key, which
	// is correct for the common (non-physical-binding) case.
	physical_key := key_from_keyval(keyval) or { input.Key.unidentified }

	// Get our modifiers for the event.
	//
	// TODO(gtk): faithful port of key.eventMods needs winproto.eventMods +
	// GdkDevice num-lock state. We translate the base GTK modifier bitmask and
	// then apply sided-modifier fixups for the modifier keys themselves, which
	// is the part of eventMods that doesn't require the device/winproto.
	mut mods := translate_mods(gtk_mods)
	self.apply_sided_mods(mut mods, physical_key, action)

	// Consumed modifiers. ghostty masks getConsumedModifiers() with the GDK
	// modifier mask and translates. Without the GdkKeyEvent accessor wired we
	// leave this empty (no consumed mods), matching the "no consumed" default.
	consumed_mods := input.Mods{}

	// If we have no UTF-8 text, try to convert the keyval to a text value.
	// GTK won't process e.g. Ctrl+Shift+1 as "Ctrl+!" but the keyval is set
	// correctly so we extract that. Control characters (< 0x20) are skipped
	// because the encoder handles them directly.
	if self.im_len == 0 && keyval_cp > 0 && keyval_cp < 0x110000 {
		cp := keyval_cp
		if cp >= 0x20 {
			encoded := utf32_to_string(cp)
			if encoded.len > 0 && encoded.len <= self.im_buf.len {
				for i in 0 .. encoded.len {
					self.im_buf[i] = encoded[i]
				}
				self.im_len = encoded.len
			}
		}
	}

	// Reset the IM buffer length after this event regardless of outcome.
	utf8 := self.im_buf[0..self.im_len].bytestr()
	defer {
		self.im_len = 0
	}

	// Invoke the core logic to handle this input.
	if !self.has_core() {
		return false
	}
	mut surface := self.core_surface
	// core.Surface.key_callback takes a core.KeyEvent (key/action/mods/utf8).
	// The richer input.KeyEvent fields (consumed_mods, composing,
	// unshifted_codepoint) are computed above but not part of the core event.
	effect := surface.key_callback(core.KeyEvent{
		action: core_key_action(action)
		key: physical_key
		mods: mods
		utf8: utf8
	}) or {
		eprintln('error in key callback err=${err}')
		return false
	}

	match effect {
		.closed {
			return true
		}
		.ignored {}
		.consumed {
			if action == .press || action == .repeat {
				// If we were composing, reset the IM context. We do NOT reset
				// otherwise because other IME state must be preserved (e.g.
				// quotation-mark ordering for Chinese input).
				if self.im_composing {
					C.gtk_im_context_reset(self.im_context)
					surface.preedit_callback('') or {}
				}
				// Bell stops ringing when a used key is pressed.
				self.set_bell_ringing(false)
				return true
			}
		}
	}

	return false
}

// apply_sided_mods applies the sided-modifier fixups for modifier keys
// themselves. Faithful port of the `switch (physical_key)` in key.eventMods:
// GTK doesn't set the main modifier when only the modifier key is pressed, but
// core logic relies on it, and we record which side.
fn (self &SurfaceWidget) apply_sided_mods(mut mods input.Mods, physical_key input.Key, action input.KeyAction) {
	pressed := action != .release
	match physical_key {
		.shift_left {
			mods.shift = pressed
			mods.sides.shift = .left
		}
		.shift_right {
			mods.shift = pressed
			mods.sides.shift = .right
		}
		.control_left {
			mods.ctrl = pressed
			mods.sides.ctrl = .left
		}
		.control_right {
			mods.ctrl = pressed
			mods.sides.ctrl = .right
		}
		.alt_left {
			mods.alt = pressed
			mods.sides.alt = .left
		}
		.alt_right {
			mods.alt = pressed
			mods.sides.alt = .right
		}
		.meta_left {
			mods.super_ = pressed
			mods.sides.super = .left
		}
		.meta_right {
			mods.super_ = pressed
			mods.sides.super = .right
		}
		else {}
	}
}

// ec_key_pressed is the GtkEventControllerKey "key-pressed" handler. Mirrors
// `ecKeyPressed`.
pub fn (mut self SurfaceWidget) ec_key_pressed(event GdkEvent, keyval u32, keycode u32, gtk_mods u32) bool {
	return self.key_event(.press, event, keyval, keycode, gtk_mods)
}

// ec_key_released is the GtkEventControllerKey "key-released" handler. Mirrors
// `ecKeyReleased`.
pub fn (mut self SurfaceWidget) ec_key_released(event GdkEvent, keyval u32, keycode u32, gtk_mods u32) {
	self.key_event(.release, event, keyval, keycode, gtk_mods)
}

// --- Input method callbacks -----------------------------------------------

// im_preedit_start begins composing. Mirrors `imPreeditStart`.
pub fn (mut self SurfaceWidget) im_preedit_start() {
	self.im_composing = true
	self.im_len = 0
}

// im_preedit_changed handles a preedit change. Mirrors `imPreeditChanged`.
// The preedit string is passed in (ghostty pulls it from the IM context).
pub fn (mut self SurfaceWidget) im_preedit_changed(str string) {
	// Any preedit change marks that we're composing.
	self.im_composing = true

	// Can't set preedit unless we have a core surface.
	if !self.has_core() {
		return
	}
	mut surface := self.core_surface
	surface.preedit_callback(str) or {
		eprintln('error in preedit callback err=${err}')
	}
}

// im_preedit_end ends composing. Mirrors `imPreeditEnd`.
pub fn (mut self SurfaceWidget) im_preedit_end() {
	self.im_composing = false
	if !self.has_core() {
		return
	}
	mut surface := self.core_surface
	surface.preedit_callback('') or {
		eprintln('error in preedit callback err=${err}')
	}
}

// im_commit handles committed IM text. Faithfully translated from `imCommit`,
// including the in_keyevent state machine that decides whether the text should
// be buffered for the key event or committed directly.
pub fn (mut self SurfaceWidget) im_commit(str string) {
	match self.in_keyevent {
		// Not in a key event: commit came from another source (OSK, tablet).
		.false_ {}
		// Composing in a key event: this commit is part of a multi-keypress
		// commit and we don't want to encode it alongside the keypress.
		.composing {}
		// Not composing: a normal key encoding; buffer it so the key event
		// handler associates it with the keypress.
		.not_composing {
			if str.len > self.im_buf.len {
				eprintln('not enough buffer space for input method commit')
				return
			}
			for i in 0 .. str.len {
				self.im_buf[i] = str[i]
			}
			self.im_len = str.len
			return
		}
	}

	// Reaching here means composing OR not in a keypress: commit directly.
	self.im_composing = false

	if !self.has_core() {
		return
	}
	mut surface := self.core_surface
	// Well-behaved IMs trigger preedit-end for us; some don't, so end it here.
	surface.preedit_callback('') or {
		eprintln('error in preedit callback err=${err}')
	}
	// Send the text with an invalid key (no PTY encoding for the key itself).
	surface.key_callback(core.KeyEvent{
		action: .press
		key: .unidentified
		mods: input.Mods{}
		utf8: str
	}) or {
		eprintln('error in key callback err=${err}')
	}
}

// --- Mouse input ----------------------------------------------------------

// translate_mouse_button converts a GTK button number to an input.MouseButton.
// Mirrors the file-scope `translateMouseButton`.
fn translate_mouse_button(button u32) input.MouseButton {
	return match button {
		1 { input.MouseButton.left }
		2 { input.MouseButton.middle }
		3 { input.MouseButton.right }
		4 { input.MouseButton.four }
		5 { input.MouseButton.five }
		6 { input.MouseButton.six }
		7 { input.MouseButton.seven }
		8 { input.MouseButton.eight }
		9 { input.MouseButton.nine }
		10 { input.MouseButton.ten }
		11 { input.MouseButton.eleven }
		else { input.MouseButton.unknown }
	}
}

// gc_mouse_down is the GtkGestureClick "pressed" handler. Mirrors `gcMouseDown`.
// `button` is the current gesture button; `event` is the current GdkEvent.
pub fn (mut self SurfaceWidget) gc_mouse_down(event GdkEvent, button u32, x f64, y f64) {
	if isnil(event) {
		return
	}

	// Bell stops ringing if any mouse button is pressed.
	self.set_bell_ringing(false)

	if !self.has_core() {
		return
	}
	mut surface := self.core_surface

	// If we don't have focus, grab it.
	if !C.gtk_widget_has_focus(self.gl_area) {
		C.gtk_widget_grab_focus(self.gl_area)
	}

	btn := translate_mouse_button(button)

	if btn == .middle && !self.gtk_enable_primary_paste {
		return
	}

	gtk_mods := C.gdk_event_get_modifier_state(event)
	mods := translate_mods(gtk_mods)
	consumed := surface.mouse_button_callback(.press, btn, mods) or {
		eprintln('error in mouse button callback err=${err}')
		false
	}

	// If a right-click isn't consumed, open the context menu.
	if !consumed && btn == .right {
		// TODO(gtk): emit `menu` signal, then set_pointing_to + popup on the
		// context_menu popover (template child) at (x, y).
		_ = x
		_ = y
	}
}

// gc_mouse_up is the GtkGestureClick "released" handler. Mirrors `gcMouseUp`.
pub fn (mut self SurfaceWidget) gc_mouse_up(event GdkEvent, button u32) {
	if isnil(event) {
		return
	}
	if !self.has_core() {
		return
	}
	mut surface := self.core_surface

	btn := translate_mouse_button(button)
	if btn == .middle && !self.gtk_enable_primary_paste {
		return
	}

	gtk_mods := C.gdk_event_get_modifier_state(event)
	mods := translate_mods(gtk_mods)
	consumed := surface.mouse_button_callback(.release, btn, mods) or {
		eprintln('error in mouse button callback err=${err}')
		return
	}

	// Trigger the on-screen keyboard if we have no selection and the callback
	// didn't intercept.
	if !consumed && btn == .left && !surface.has_selection() {
		// TODO(gtk): activate the on-screen keyboard via im_context.activateOsk.
	}
}

// ec_mouse_motion is the GtkEventControllerMotion "motion" handler. Mirrors
// `ecMouseMotion`.
pub fn (mut self SurfaceWidget) ec_mouse_motion(event GdkEvent, x f64, y f64) {
	if isnil(event) {
		return
	}

	sx, sy := self.scaled_coordinates(x, y)
	pos := apprt.CursorPos{
		x: f32(sx)
		y: f32(sy)
	}

	// GTK issues motion events without the cursor actually moving in a couple
	// cases (GLArea resized under the mouse; title updated). Only continue if
	// the cursor actually moved.
	is_cursor_still := abs_f32(self.cursor_pos.x - pos.x) < 1 && abs_f32(self.cursor_pos.y - pos.y) < 1
	if is_cursor_still {
		return
	}

	// If we don't have focus and focus-follows-mouse is on, grab it.
	// TODO(gtk): gate on config.@"focus-follows-mouse" once witty's
	// configpkg.Config carries that field.
	if !isnil(self.config) && !C.gtk_widget_has_focus(self.gl_area) {
		// C.gtk_widget_grab_focus(self.gl_area)
	}

	// Our pos changed, update.
	self.cursor_pos = pos

	if self.has_core() {
		mut surface := self.core_surface
		gtk_mods := C.gdk_event_get_modifier_state(event)
		mods := translate_mods(gtk_mods)
		surface.cursor_pos_callback(core.CursorPos{ x: self.cursor_pos.x, y: self.cursor_pos.y },
			mods) or {
			eprintln('error in cursor pos callback err=${err}')
		}
	}
}

// ec_mouse_leave is the GtkEventControllerMotion "leave" handler. Mirrors
// `ecMouseLeave`: sends an out-of-bounds cursor position.
pub fn (mut self SurfaceWidget) ec_mouse_leave(event GdkEvent) {
	if isnil(event) {
		return
	}
	if self.has_core() {
		mut surface := self.core_surface
		gtk_mods := C.gdk_event_get_modifier_state(event)
		mods := translate_mods(gtk_mods)
		surface.cursor_pos_callback(core.CursorPos{ x: -1, y: -1 }, mods) or {
			eprintln('error in cursor pos callback err=${err}')
		}
	}
}

// --- Scroll input ---------------------------------------------------------

// ec_scroll_vertical_precision_begin marks a precision scroll in progress.
// Mirrors `ecMouseScrollVerticalPrecisionBegin`.
pub fn (mut self SurfaceWidget) ec_scroll_vertical_precision_begin() {
	self.precision_scroll = true
}

// ec_scroll_vertical_precision_end clears the precision scroll flag. Mirrors
// `ecMouseScrollVerticalPrecisionEnd`.
pub fn (mut self SurfaceWidget) ec_scroll_vertical_precision_end() {
	self.precision_scroll = false
}

// ec_scroll_vertical is the GtkEventControllerScroll "scroll" handler for
// vertical scroll. Mirrors `ecMouseScrollVertical`.
pub fn (mut self SurfaceWidget) ec_scroll_vertical(x f64, y f64) bool {
	if !self.has_core() {
		return false
	}
	mut surface := self.core_surface

	// Multiply precision scrolls by 10 for a better touchpad response.
	multiplier := if self.precision_scroll { f64(10.0) } else { f64(1.0) }

	sx, sy := self.scaled_coordinates(x, y)
	// We invert because we apply natural scrolling to the values.
	// core.Surface.scroll_callback takes a `precision bool` rather than the
	// full input.ScrollMods (momentum is not consumed by the core yet).
	surface.scroll_callback(sx * -1 * multiplier, sy * -1 * multiplier, self.precision_scroll) or {
		eprintln('error in scroll callback err=${err}')
		return false
	}
	return true
}

// ec_scroll_horizontal is the GtkEventControllerScroll "scroll" handler for
// horizontal scroll. Mirrors `ecMouseScrollHorizontal`: accumulates horizontal
// scroll and switches tabs when the threshold is crossed. The 500ms reset timer
// is stubbed (needs a glib timeout source).
pub fn (mut self SurfaceWidget) ec_scroll_horizontal(x f64) bool {
	self.pending_horizontal_scroll += x

	if abs_f64(self.pending_horizontal_scroll) < 120 {
		// TODO(gtk): (re)arm a 500ms glib timeout to reset pending scroll.
		return true
	}

	// TODO(gtk): activate "tab.next-page" / "tab.previous-page" action based on
	// the sign of pending_horizontal_scroll.
	self.pending_horizontal_scroll = 0.0
	return true
}

// --- Focus event controllers ----------------------------------------------

// ec_focus_enter is the GtkEventControllerFocus "enter" handler. Mirrors
// `ecFocusEnter`.
pub fn (mut self SurfaceWidget) ec_focus_enter() {
	self.focused = true
	C.gtk_im_context_focus_in(self.im_context)
	self.notify_focus()
	// TODO(gtk): notifyByPspec(properties.focused).
	// Bell stops ringing as soon as we gain focus.
	self.set_bell_ringing(false)
}

// ec_focus_leave is the GtkEventControllerFocus "leave" handler. Mirrors
// `ecFocusLeave`.
pub fn (mut self SurfaceWidget) ec_focus_leave() {
	self.focused = false
	C.gtk_im_context_focus_out(self.im_context)
	self.notify_focus()
	// TODO(gtk): notifyByPspec(properties.focused).
}

// notify_focus forwards the focus state to the core surface. In ghostty this is
// deferred onto a glib idle source (idleFocus) to avoid a deadlock where a
// libghostty callback triggers focus loss while a lock is held. We invoke it
// directly here; the idle-source deferral is stubbed.
fn (self &SurfaceWidget) notify_focus() {
	// TODO(gtk): defer onto glib.idleAddOnce(idleFocus) as in ghostty.
	if !self.has_core() {
		return
	}
	mut surface := self.core_surface
	surface.focus_callback(self.focused) or {
		eprintln('error in focus callback err=${err}')
	}
}

// --- GLArea lifecycle -----------------------------------------------------

// glarea_realize is the GtkGLArea "realize" handler. Mirrors `glareaRealize`.
pub fn (mut self SurfaceWidget) glarea_realize() {
	// Make the GL area current so we can detect OpenGL errors.
	C.gtk_gl_area_make_current(self.gl_area)
	gl_err := C.gtk_gl_area_get_error(self.gl_area)
	if !isnil(gl_err) {
		eprintln('failed to make GL context current; switching to error state')
		self.set_error(true)
		return
	}

	// If we already have an initialized surface, notify it; otherwise we'll
	// initialize on the first resize so we have proper initial dimensions.
	if self.has_core() {
		// TODO(gtk): core.Surface has no display_realized; the renderer's
		// display-realized hook is not exposed as a public Surface method.
		self.redraw()
	}

	// Setup our input method (strong ref back to us; released in unrealize).
	C.gtk_im_context_set_client_widget(self.im_context, self.widget)
}

// glarea_unrealize is the GtkGLArea "unrealize" handler. Mirrors
// `glareaUnrealize`.
pub fn (mut self SurfaceWidget) glarea_unrealize() {
	if self.has_core() {
		// The context is not guaranteed current on unrealize, so make it current.
		C.gtk_gl_area_make_current(self.gl_area)
		gl_err := C.gtk_gl_area_get_error(self.gl_area)
		if !isnil(gl_err) {
			eprintln('gl_area_make_current failed in unrealize; resources likely leaked')
			return
		}
		// TODO(gtk): core.Surface has no display_unrealized; the renderer's
		// display-unrealized hook is not exposed as a public Surface method.
	}

	// Unset our input method.
	C.gtk_im_context_set_client_widget(self.im_context, unsafe { nil })
}

// glarea_render is the GtkGLArea "render" handler. Mirrors `glareaRender`.
// Returns true (GDK_EVENT_STOP-equivalent) as in the Zig original.
pub fn (mut self SurfaceWidget) glarea_render() bool {
	if !self.has_core() {
		return true
	}
	mut surface := self.core_surface
	// core.Surface.draw() draws a single frame (renderer.draw_frame(true)).
	surface.draw() or {
		eprintln('failed to draw frame err=${err}')
		return false
	}
	return true
}

// glarea_resize is the GtkGLArea "resize" handler. Mirrors `glareaResize`.
// Stores the cached size and either forwards resize callbacks to the core
// surface or initializes the surface on the first resize.
pub fn (mut self SurfaceWidget) glarea_resize(width int, height int) {
	// Store our cached size.
	self.size = apprt.SurfaceSize{
		width: u32(width)
		height: u32(height)
	}

	// If our surface is realized, send callbacks.
	if self.has_core() {
		mut surface := self.core_surface
		// Update content scale too (no dedicated signal for it).
		scale := self.get_content_scale() or { apprt.ContentScale{
			x: 1.0
			y: 1.0
		} }
		surface.content_scale_callback(core.ContentScale{ x: scale.x, y: scale.y }) or {
			eprintln('error in content scale callback err=${err}')
		}
		// core.Surface.size_callback takes width/height in pixels, not a struct.
		surface.size_callback(self.size.width, self.size.height) or {
			eprintln('error in size callback err=${err}')
		}
		// TODO(gtk): schedule the resize overlay if configured.
		return
	}

	// If we don't have a surface, initialize it now.
	self.init_surface() or {
		eprintln('surface failed to initialize err=${err}')
	}
}

// init_surface initializes the core surface on the first GLArea resize.
// Mirrors `initSurface`. The bulk (creating/initializing the core Surface,
// cgroup, config wiring) needs `main.Surface`/Application which are out of
// scope, so those are stubbed; the structure and error handling are kept.
fn (mut self SurfaceWidget) init_surface() ! {
	if self.has_core() {
		return
	}

	// Make the GL context current for surface operations.
	C.gtk_gl_area_make_current(self.gl_area)
	gl_err := C.gtk_gl_area_get_error(self.gl_area)
	if !isnil(gl_err) {
		return error('failed to make GL context current')
	}

	// TODO(gtk): initialize the cgroup, allocate + init a core.Surface via
	// apprt.surface.newConfig / core.Surface.init, add it to the app surface
	// list, store it in self.core_surface, and emit the `init` signal. This
	// requires the Application GObject wiring which is out of scope here.
}

// --- Clipboard ------------------------------------------------------------

// clipboard_for returns the GdkClipboard for the given apprt clipboard type.
// Mirrors the `Clipboard.get` helper.
fn (self &SurfaceWidget) clipboard_for(clipboard apprt.Clipboard) GdkClipboard {
	return match clipboard {
		.standard { C.gtk_widget_get_clipboard(self.gl_area) }
		.selection, .primary { C.gtk_widget_get_primary_clipboard(self.gl_area) }
	}
}

// set_clipboard sets the clipboard contents. Mirrors `Surface.setClipboard` +
// `Clipboard.set`. The multi-provider (MIME) union path and the confirmation
// dialog path need the gdk.ContentProvider machinery and the confirmation
// dialog GObject; here we implement the common plaintext no-confirm path and
// stub the rest.
pub fn (mut self SurfaceWidget) set_clipboard(clipboard_type apprt.Clipboard, contents []apprt.ClipboardContent, confirm bool) {
	// Grab the plaintext content used for signals and confirmation dialogs.
	mut text := ''
	mut found := false
	for content in contents {
		if content.mime == 'text/plain' {
			text = content.data
			found = true
			break
		}
	}
	if !found {
		return
	}

	if !confirm {
		clipboard := self.clipboard_for(clipboard_type)
		if isnil(clipboard) {
			return
		}
		// TODO(gtk): build a gdk.ContentProvider union over all MIME types as
		// in ghostty; for now set the plaintext content directly.
		C.gdk_clipboard_set_text(clipboard, text.str)
		// TODO(gtk): emit `clipboard-write` signal (clipboard_type, text).
		return
	}

	// TODO(gtk): show the clipboard confirmation dialog (osc_52_write).
}

// clipboard_request requests clipboard contents (reads the clipboard). Mirrors
// `Surface.clipboardRequest` + `Clipboard.request`. The async read + completion
// wiring (readTextAsync, completeClipboardRequest) is stubbed; the synchronous
// early-outs are preserved.
pub fn (mut self SurfaceWidget) clipboard_request(clipboard_type apprt.Clipboard, state apprt.ClipboardRequest) !bool {
	clipboard := self.clipboard_for(clipboard_type)
	if isnil(clipboard) {
		return false
	}

	// TODO(gtk): for paste requests, verify the clipboard has a text format via
	// gdk.Clipboard.getFormats().containGtype(string); if not, return false so
	// performable keybinds can pass through.
	//
	// TODO(gtk): allocate a Request (reffing self), then
	// gdk.Clipboard.readTextAsync(..., clipboardReadText, ud) and, on
	// completion, call core.completeClipboardRequest(state, str, false).
	_ = state
	return true
}

// --- Gtk.Scrollable adjustments -------------------------------------------

// get_hadjustment returns the horizontal adjustment. Mirrors
// `Surface.getHAdjustment`.
pub fn (self &SurfaceWidget) get_hadjustment() GtkAdjustment {
	return self.hadj
}

// set_hadjustment sets the horizontal adjustment (reffed). Mirrors
// `Surface.setHAdjustment`.
pub fn (mut self SurfaceWidget) set_hadjustment(adj GtkAdjustment) {
	if !isnil(self.hadj) {
		object_unref(self.hadj)
		self.hadj = unsafe { nil }
	}
	if isnil(adj) {
		return
	}
	object_ref(adj)
	self.hadj = adj
}

// get_vadjustment returns the vertical adjustment. Mirrors
// `Surface.getVAdjustment`.
pub fn (self &SurfaceWidget) get_vadjustment() GtkAdjustment {
	return self.vadj
}

// set_vadjustment sets the vertical adjustment (reffed). Mirrors
// `Surface.setVAdjustment`.
pub fn (mut self SurfaceWidget) set_vadjustment(adj GtkAdjustment) {
	if !isnil(self.vadj) {
		object_unref(self.vadj)
		self.vadj = unsafe { nil }
	}
	if isnil(adj) {
		return
	}
	object_ref(adj)
	self.vadj = adj
	// TODO(gtk): lazily set up the "value-changed" signal group as in
	// propVAdjustment, forwarding to scroll_to_row on the core surface.
}

// --- Signal emitters (stubs) ----------------------------------------------
// These emit GObject signals in ghostty; here they are minimal stubs with
// faithful names/signatures so callers type-check.

// close requests the surface be closed. Mirrors `Surface.close` (emits
// `close-request`).
pub fn (self &SurfaceWidget) close() {
	// TODO(gtk): emit `close-request` signal.
}

// present requests this surface come to the front. Mirrors `Surface.present`
// (emits `present-request`).
pub fn (self &SurfaceWidget) present() {
	// TODO(gtk): emit `present-request` signal.
}

// toggle_fullscreen requests the container toggle fullscreen. Mirrors
// `Surface.toggleFullscreen` (emits `toggle-fullscreen`).
pub fn (self &SurfaceWidget) toggle_fullscreen() {
	// TODO(gtk): emit `toggle-fullscreen` signal.
}

// toggle_maximize requests the container toggle maximize. Mirrors
// `Surface.toggleMaximize` (emits `toggle-maximize`).
pub fn (self &SurfaceWidget) toggle_maximize() {
	// TODO(gtk): emit `toggle-maximize` signal.
}

// redraw_inspector redraws the inspector, if any. Mirrors
// `Surface.redrawInspector`.
pub fn (self &SurfaceWidget) redraw_inspector() {
	// TODO(gtk): queue a render on the inspector window if present.
}

// --- GObject class registration (stub) ------------------------------------
//
// TODO(gtk): In ghostty, the class is registered via
// gobject.ext.defineClass(...) with an instanceInit, classInit, a Private
// struct, and the gtk.Scrollable interface. classInit loads the blueprint
// `.ui` template (setTemplateFromResource), binds template children
// (gl_area, im_context, url_left/right, context_menu, drop_target,
// progress_bar_overlay, error_page, terminal_page, resize/search/key-state
// overlays, child_exited_overlay), binds template callbacks (the ec_*/gc_*/
// glarea_*/im_* handlers above), and registers properties/signals.
//
// V has no such machinery, so type registration, `.ui`/blueprint templates,
// property/signal registration, and template-child binding are all stubbed.
// The handlers above are plain methods rather than C template callbacks.

// new_surface_widget creates a new SurfaceWidget. Mirrors `Surface.new`
// (gobject.ext.newInstance). Here it just returns a value-initialized struct
// with the private-field defaults set (matching the Zig `init`).
pub fn new_surface_widget() &SurfaceWidget {
	mut w := &SurfaceWidget{}
	w.rt_surface = Surface{}
	w.mouse_shape = .text
	w.focused = true
	w.in_keyevent = .false_
	w.gtk_enable_primary_paste = true
	return w
}

// --- small numeric helpers ------------------------------------------------

fn abs_f32(v f32) f32 {
	return if v < 0 { -v } else { v }
}

fn abs_f64(v f64) f64 {
	return if v < 0 { -v } else { v }
}
