module gtk

// window_linux.v - The GObject Window class for the GTK apprt.
//
// Translated from ghostty/src/apprt/gtk/class/window.zig.
//
// The Zig original is a GObject class (`GhosttyWindow`, an
// `adw.ApplicationWindow`) that hosts the tabs + split tree for a Ghostty
// window. It is registered via `gobject.ext.defineClass`, uses a blueprint
// `.ui` template for its widget tree (AdwTabOverview / AdwTabBar / AdwTabView /
// AdwToolbarView / AdwToastOverlay), and wires up a large number of GObject
// signal handlers, properties, and template callbacks.
//
// V has no GObject class-registration / `.ui`-template machinery, and the
// `gtk` module cannot import witty's root `module main`. So per the translation
// plan:
//
//   * The class is modeled as a plain V struct `Window` that wraps the
//     underlying GObject/GtkWindow pointer plus the private-state fields, with
//     the class methods translated as `pub fn`.
//   * GObject type registration, the property system, signal-handler
//     connection, `.ui`/blueprint templates, and the AdwTabView/AdwTabBar
//     widget wiring are STUBBED with `// TODO(gtk)` and minimal type-checking
//     bodies (or C calls where a plain GTK/Adw function exists).
//   * The TRACTABLE structural logic IS translated: tab position selection,
//     tab selection/move arithmetic, fullscreen/maximize toggling, the
//     dynamic appearance getters (headerbar-visible, tabs-*, toolbar/titlebar
//     style), config application, and the winproto integration.
//
// Cross-class references:
//   * `Application` is the GObject application class (app_linux.v placeholder).
//   * `Surface` is the apprt surface adapter (surface_linux.v). The GObject
//     surface widget class is stubbed as `GtkSurface` there.
//   * `Config` (the GObject config wrapper, class/config.zig) is modeled here
//     as a small placeholder wrapping `&configpkg.Config` with a `.get()`
//     accessor, extended with the GTK-specific config getters that witty's
//     core `configpkg.Config` does not yet carry.
//   * The winproto placeholder `ApprtWindow` (winproto_linux.v) stands in for
//     the pointer that winproto backends receive; this `Window` owns a
//     `WinProtoWindow` and an `ApprtWindow` bridge for that integration.
//   * `Tab`, `SplitTree`, `CommandPalette`, `CloseConfirmationDialog`, and the
//     AdwTabView/AdwTabPage widgets are out of scope; they are referenced via
//     opaque handle aliases and `// TODO(gtk)` stubs.

import configpkg
import core

// --- New opaque handle aliases --------------------------------------------
// (Grep-verified: none of these `fn C.*` or aliases are declared elsewhere in
// the module.)

// AdwApplicationWindow is an AdwApplicationWindow* (the parent instance type).
pub type AdwApplicationWindow = voidptr

// AdwTabView is an AdwTabView*.
pub type AdwTabView = voidptr

// AdwTabBar is an AdwTabBar*.
pub type AdwTabBar = voidptr

// AdwTabOverview is an AdwTabOverview*.
pub type AdwTabOverview = voidptr

// AdwTabPage is an AdwTabPage*.
pub type AdwTabPage = voidptr

// AdwToolbarView is an AdwToolbarView*.
pub type AdwToolbarView = voidptr

// AdwToastOverlay is an AdwToastOverlay*.
pub type AdwToastOverlay = voidptr

// GtkNative is a gtk.Native* (interface) — the upcast used to reach the
// GdkSurface of a realized window.
pub type GtkNative = voidptr

// --- New GTK/Adw C bindings -----------------------------------------------
// Only functions not already declared anywhere in the module.

fn C.gtk_window_set_title(window GtkWindow, title &char)
fn C.gtk_window_get_title(window GtkWindow) &char
fn C.gtk_window_set_icon_name(window GtkWindow, name &char)
fn C.gtk_window_maximize(window GtkWindow)
fn C.gtk_window_unmaximize(window GtkWindow)
fn C.gtk_window_is_maximized(window GtkWindow) int
fn C.gtk_window_fullscreen(window GtkWindow)
fn C.gtk_window_unfullscreen(window GtkWindow)
fn C.gtk_window_is_fullscreen(window GtkWindow) int
fn C.gtk_window_is_active(window GtkWindow) int
fn C.gtk_window_set_decorated(window GtkWindow, decorated int)
fn C.gtk_window_set_default_size(window GtkWindow, width int, height int)
fn C.gtk_window_present(window GtkWindow)
fn C.gtk_window_close(window GtkWindow)
fn C.gtk_window_destroy(window GtkWindow)

fn C.gtk_widget_add_css_class(widget GtkWidget, css_class &char)
fn C.gtk_widget_remove_css_class(widget GtkWidget, css_class &char)
fn C.gtk_widget_set_visible(widget GtkWidget, visible int)
fn C.gtk_widget_get_visible(widget GtkWidget) int
fn C.gtk_widget_set_size_request(widget GtkWidget, width int, height int)

fn C.gdk_display_is_rgba(display GdkDisplay) int
fn C.gdk_display_is_composited(display GdkDisplay) int

// --- Toolbar style ---------------------------------------------------------

// AdwToolbarStyle mirrors `adw.ToolbarStyle`.
pub enum AdwToolbarStyle {
	flat
	raised
	raised_border
}

// NewSurfaceContext mirrors `apprt.surface.NewSurfaceContext`. The `apprt`
// module is not imported here (to avoid a cross-module dependency in the
// widget class); this local placeholder keeps the `new_tab_page` signature
// faithful.
pub enum NewSurfaceContext {
	window
	tab
	split
}

// --- Config: GObject config wrapper (owned elsewhere) ---------------------
//
// The canonical `Config` GObject wrapper (translated from class/config.zig)
// now lives in config_class_linux.v, which owns the type, `config_new`, the
// `.get()`/`.get_mut()` accessors, and the GTK-specific config getters
// (gtk_titlebar_style, gtk_wide_tabs, ...) that the appearance logic below
// uses. This file references `Config` directly (same `gtk` module).

// --- SelectTab ------------------------------------------------------------

// SelectTabKind mirrors the tag of the Zig `SelectTab` union.
pub enum SelectTabKind {
	previous
	next
	last
	n
}

// SelectTab mirrors the Zig `SelectTab = union(enum)`. When `kind == .n` the
// `n` field carries the (1-indexed) tab number.
pub struct SelectTab {
pub:
	kind SelectTabKind
	n    usize
}

// --- Window ---------------------------------------------------------------

// Window is the apprt window GObject (`GhosttyWindow`, an
// `adw.ApplicationWindow`). Modeled as a struct wrapping the GObject pointer
// plus the private-state fields from the Zig `Private` struct.
//
// `@[heap]` so the winproto integration can hold a stable pointer to the
// embedded `ApprtWindow` bridge (mirroring ghostty passing a `*Window`).
@[heap]
pub struct Window {
mut:
	// The underlying AdwApplicationWindow GObject. Set at construction by the
	// (stubbed) GObject instance init.
	obj AdwApplicationWindow = unsafe { nil }

	// Whether this window is a quick terminal. If it is then it behaves
	// slightly differently under certain scenarios.
	quick_terminal bool

	// The window decoration override. If this is not set then we inherit
	// whatever the config has. This allows overriding the config on a
	// per-window basis. `has_window_decoration` gates whether it is set (V has
	// no `?enum` field ergonomics matching the Zig `?WindowDecoration`).
	window_decoration     configpkg.WindowDecoration = .auto
	has_window_decoration bool

	// The configuration that this window is using.
	config &Config = unsafe { nil }

	// State and logic for windowing protocol for a window.
	winproto WinProtoWindow

	// The bridge object that winproto backends receive. Mirrors ghostty
	// passing `*Window` to winproto (which only calls the small accessor set
	// modeled by `ApprtWindow`).
	apprt_window ApprtWindow

	// Kind of hacky, but this lets us know if we've initialized any single
	// surface yet. We gate default size on this so we don't resize the window
	// after surfaces already exist.
	surface_init bool

	// See tab_overview_open for why we have this. 0 means "no timer".
	tab_overview_focus_timer u32

	// A weak reference to a command palette.
	command_palette WeakRef = weak_ref_empty()

	// Template children (out of scope widgets). Populated by the stubbed
	// template init.
	tab_overview  AdwTabOverview  = unsafe { nil }
	tab_bar       AdwTabBar       = unsafe { nil }
	tab_view      AdwTabView      = unsafe { nil }
	toolbar       AdwToolbarView  = unsafe { nil }
	toast_overlay AdwToastOverlay = unsafe { nil }
}

// new creates a new Window GObject for the given application. Mirrors
// `Window.new`.
//
// TODO(gtk): the Zig original uses `gobject.ext.newInstance(Self, ...)` which
// constructs the GObject, runs the template init, and sets the `application`
// property. That GObject machinery has no V equivalent; here we allocate the
// struct and run the tractable parts of `init`.
pub fn Window.new(app &Application) &Window {
	mut self := &Window{}
	self.init(app)
	return self
}

// init runs the tractable parts of the Zig `init` instanceInit. Mirrors the
// non-GObject-machinery portions: config fallback, winproto reset, tab-binding
// intent, window icon, action map, initial config-driven state (maximize /
// fullscreen / title), and the final appearance sync.
fn (mut self Window) init(app &Application) {
	// TODO(gtk): gtk.Widget.initTemplate(...) builds the widget tree from the
	// blueprint `.ui` template (AdwTabOverview/TabBar/TabView/ToolbarView/
	// ToastOverlay) and populates the template children. Out of scope.

	// If our configuration is null then we get it from the application.
	if self.config == unsafe { nil } {
		self.config = config_new(app.get_config())
	}

	// We initialize our windowing protocol to none because we can't actually
	// initialize this until we get realized.
	self.winproto = WinProtoWindow{
		protocol: .none_
	}

	// Add our dev CSS class if we're in debug mode.
	$if !prod {
		self.add_css_class('devel')
	}

	// TODO(gtk): setup the tab binding group (gobject.BindingGroup) that syncs
	// the "title" property from the currently active tab. GObject bindings are
	// out of scope.

	// Set our window icon.
	self.set_icon_name(application_id)

	// Initialize our actions.
	self.init_action_map()

	// Start states based on config.
	if self.config != unsafe { nil } {
		config := self.config.get()
		if config.maximize {
			self.maximize()
		}
		if config.fullscreen {
			self.fullscreen()
		}
		// If we have an explicit title set, we set that immediately so that
		// any applications inspecting the window states see an immediate title
		// set when the window appears.
		if title := config.title {
			self.set_title(title)
		}
	}

	// Keep the winproto bridge's view of config/quick-terminal/decoration in
	// sync so the winproto integration sees consistent state.
	self.sync_apprt_window()

	// We always sync our appearance at the end because loading our config can
	// affect bindings set up initially in initTemplate.
	self.sync_appearance()

	// TODO(gtk): notifyByPspec("active-surface") to initialize the dynamic
	// title getter. GObject property system out of scope.
}

// init_action_map sets up our action map. Mirrors `initActionMap`.
//
// TODO(gtk): the actual action callbacks are C trampolines bound to this
// GObject via `ext.actions.add`. Those trampolines and the GObject action-map
// upcast are out of scope. We keep the action name table for parity.
fn (mut self Window) init_action_map() {
	// The action names, mirroring the Zig `actions` array. The callbacks are
	// stubbed (see the `action_*` methods below), so this list documents the
	// intended surface of the window's action map.
	_ = [
		'about',
		'close',
		'close-tab',
		'new-tab',
		'new-window',
		'ring-bell',
		'split-right',
		'split-left',
		'split-up',
		'split-down',
		'copy',
		'paste',
		'reset',
		'clear',
		'toggle-command-palette',
		'toggle-inspector',
	]
}

// sync_apprt_window mirrors the winproto bridge into the current window state.
// (Not present in the Zig original, which passes `*Window` directly; here the
// bridge caches the small accessor set that winproto reads.)
fn (mut self Window) sync_apprt_window() {
	self.apprt_window.quick_terminal = self.quick_terminal
	self.apprt_window.decoration = self.get_window_decoration()
	if self.config != unsafe { nil } {
		self.apprt_window.config = self.config.get()
	}
}

// --- Winproto -------------------------------------------------------------

// winproto returns the winproto backend for this window. Mirrors `winproto`.
pub fn (mut self Window) winproto() &WinProtoWindow {
	return &self.winproto
}

// --- Tab management -------------------------------------------------------

// new_tab creates a new tab with the given parent, inserted at the position
// dictated by `window-new-tab-position`. The new tab is selected. Mirrors
// `newTab`.
pub fn (mut self Window) new_tab(parent &core.Surface) {
	self.new_tab_page(parent, .tab)
}

// new_tab_for_window mirrors `newTabForWindow`.
pub fn (mut self Window) new_tab_for_window(parent &core.Surface) {
	self.new_tab_page(parent, .window)
}

// new_tab_page creates a Tab, computes its insert position from the config,
// inserts + selects it, and wires up its bindings/signals. Mirrors
// `newTabPage`.
//
// TODO(gtk): the Tab GObject, AdwTabView insert/select, property bindings, and
// the SplitTree "changed" signal are out of scope. The tractable part — the
// insert-position computation from `window-new-tab-position` — is translated
// against the AdwTabView C API. Returns the (opaque) AdwTabPage.
fn (mut self Window) new_tab_page(parent &core.Surface, context NewSurfaceContext) AdwTabPage {
	_ = parent
	_ = context
	tab_view := self.tab_view

	// TODO(gtk): create the Tab GObject (gobject.ext.newInstance(Tab, ...)),
	// set its parent-with-context, bind title/tooltip, connect SplitTree
	// "changed". Out of scope.

	// Compute the position to insert at.
	if self.config == unsafe { nil } {
		// If we don't have a config we just append at the end. This should
		// never happen.
		return adw_tab_view_append(tab_view, unsafe { GtkWidget(nil) })
	}
	position := match self.config.window_new_tab_position() {
		.current {
			selected := adw_tab_view_get_selected_page(tab_view)
			if selected == unsafe { nil } {
				adw_tab_view_get_n_pages(tab_view)
			} else {
				adw_tab_view_get_page_position(tab_view, selected) + 1
			}
		}
		.end {
			adw_tab_view_get_n_pages(tab_view)
		}
	}

	// Add the page and select it.
	page := adw_tab_view_insert(tab_view, unsafe { GtkWidget(nil) }, position)
	adw_tab_view_set_selected_page(tab_view, page)
	return page
}

// select_tab selects the tab as requested. Returns true if the tab selection
// changed. Mirrors `selectTab` — this is pure position arithmetic and is fully
// translated.
pub fn (mut self Window) select_tab(n SelectTab) bool {
	tab_view := self.tab_view

	// Get our current tab numeric position.
	selected := adw_tab_view_get_selected_page(tab_view)
	if selected == unsafe { nil } {
		return false
	}
	current := adw_tab_view_get_page_position(tab_view, selected)

	// Get our total.
	total := adw_tab_view_get_n_pages(tab_view)

	target := match n.kind {
		.previous {
			if current > 0 { current - 1 } else { total - 1 }
		}
		.next {
			if current < total - 1 { current + 1 } else { 0 }
		}
		.last {
			total - 1
		}
		.n {
			// 1-indexed
			if n.n == 0 {
				return false
			}
			if n.n > usize(2147483647) {
				return false
			}
			n_int := int(n.n)
			if n_int - 1 < total - 1 { n_int - 1 } else { total - 1 }
		}
	}
	if target < 0 || target >= total {
		// Assertion in Zig; guard defensively here.
		return false
	}

	// If our target is the same as our current then we do nothing.
	if target == current {
		return false
	}

	// Get the page and select it.
	page := adw_tab_view_get_nth_page(tab_view, target)
	adw_tab_view_set_selected_page(tab_view, page)
	return true
}

// move_tab moves the tab containing the given surface by the given amount.
// Returns whether this affected any tab positioning. Mirrors `moveTab`. The
// wrap-around position arithmetic is fully translated.
pub fn (mut self Window) move_tab(surface &Surface, amount i64) bool {
	_ = surface
	tab_view := self.tab_view

	// If we have one tab we never move.
	total := adw_tab_view_get_n_pages(tab_view)
	if total == 1 {
		return false
	}

	// TODO(gtk): resolve the Tab that contains the surface via
	// ext.getAncestor(Tab, surface.as(gtk.Widget)). Out of scope; use a nil
	// tab widget placeholder for the position computation.
	tab_widget := unsafe { GtkWidget(nil) }

	// Get the page position that contains the tab.
	page := adw_tab_view_get_page(tab_view, tab_widget)
	pos := adw_tab_view_get_page_position(tab_view, page)

	// Move it (with wrap-around).
	initial := int(i64(pos) + amount)
	max := total - 1
	desired_pos := if initial < 0 {
		max + initial + 1
	} else if initial > max {
		initial - max - 1
	} else {
		initial
	}
	if desired_pos < 0 || desired_pos >= total {
		return false
	}

	return adw_tab_view_reorder_page(tab_view, page, desired_pos) != 0
}

// toggle_tab_overview toggles the tab overview open state. Mirrors
// `toggleTabOverview`.
pub fn (mut self Window) toggle_tab_overview() {
	tab_overview := self.tab_overview
	is_open := adw_tab_overview_get_open(tab_overview) != 0
	adw_tab_overview_set_open(tab_overview, b2i(!is_open))
}

// toggle_visibility toggles the window's visible property. Mirrors
// `toggleVisibility`.
pub fn (mut self Window) toggle_visibility() {
	widget := self.as_widget()
	visible := C.gtk_widget_get_visible(widget) != 0
	C.gtk_widget_set_visible(widget, b2i(!visible))
}

// --- Appearance -----------------------------------------------------------

// sync_appearance updates various appearance properties. This should always be
// safe to call multiple times, whenever a change happens that might affect how
// the window appears (config change, fullscreen, etc.). Mirrors
// `syncAppearance`.
fn (mut self Window) sync_appearance() {
	widget := self.as_widget()

	// Toggle style classes based on whether we're using CSDs or SSDs.
	// (See https://docs.gtk.org/gtk4/class.Window.html#css-nodes.)
	{
		// Reset all style classes first.
		for class in ['ssd', 'csd', 'solid-csd', 'no-border-radius'] {
			self.remove_css_class(class)
		}

		csd_enabled := self.winproto.client_side_decoration_enabled()
		C.gtk_window_set_decorated(self.as_window(), b2i(csd_enabled))

		if csd_enabled {
			display := C.gtk_widget_get_display(widget)

			// We do the exact same check GTK does internally and toggle either
			// the `csd` or `solid-csd` style, based on whether the user's window
			// manager is deemed non-compositing. In practice this only impacts
			// users of traditional X11 window managers.
			if C.gdk_display_is_rgba(display) != 0 && C.gdk_display_is_composited(display) != 0 {
				self.add_css_class('csd')
			} else {
				self.add_css_class('solid-csd')
			}
		} else {
			self.add_css_class('ssd')
			// Fix any artifacting that may occur in window corners.
			self.add_css_class('no-border-radius')
		}
	}

	// TODO(gtk): notifyByPspec for the dynamic config-driven properties
	// (headerbar-visible, tabs-autohide, tabs-visible, tabs-wide,
	// toolbar-style, titlebar-style). GObject property system out of scope; the
	// getters below (get_headerbar_visible, etc.) are the tractable logic.

	// Remainder uses the config.
	if self.config == unsafe { nil } {
		return
	}
	config := self.config.get()

	// Only add a solid background if we're opaque.
	self.toggle_css_class('background', config.background_opacity >= 1)

	// Apply class to color headerbar if window-theme is `ghostty` and GTK is
	// before 4.16. Above 4.16 we use GTK CSS color variables.
	self.toggle_css_class('window-theme-ghostty', !gtk_at_least(4, 16, 0)
		&& config.window_theme == .ghostty)

	// Move the tab bar to the proper location.
	adw_toolbar_view_remove(self.toolbar, self.as_tab_bar_widget())
	match self.config.gtk_tabs_location() {
		.top { adw_toolbar_view_add_top_bar(self.toolbar, self.as_tab_bar_widget()) }
		.bottom { adw_toolbar_view_add_bottom_bar(self.toolbar, self.as_tab_bar_widget()) }
	}

	// Do our window-protocol specific appearance sync.
	self.winproto.sync_appearance() or {
		// log.warn: failed to sync winproto appearance
	}
}

// sync_actions syncs the state of any actions on this window. Mirrors
// `syncActions`.
//
// TODO(gtk): the gio.ActionMap upcast + SimpleAction lookup/setEnabled are out
// of scope. The tractable part — computing whether the active surface has a
// selection — is retained but ends at the (stubbed) core surface.
fn (mut self Window) sync_actions() {
	// has_selection := ... self.get_active_surface()?.core()?.has_selection()
	// TODO(gtk): enable/disable the "copy" action based on has_selection.
}

// toggle_css_class adds or removes a CSS class based on `value`. Mirrors
// `toggleCssClass`.
fn (mut self Window) toggle_css_class(class string, value bool) {
	if value {
		self.add_css_class(class)
	} else {
		self.remove_css_class(class)
	}
}

// perform_binding_action performs a binding action on the window's active
// surface. Mirrors `performBindingAction`.
//
// TODO(gtk): resolving the active surface's core and calling
// `core_surface.performBindingAction(action)` is out of scope (core types are
// placeholders). Kept as a faithful stub. `action` is an opaque action tag.
fn (mut self Window) perform_binding_action(action BindingActionTag) {
	_ = action
	// surface := self.get_active_surface() or { return }
	// core := surface.core() ...
}

// add_toast queues a simple text-based toast. All text-based toasts share the
// same timeout for consistency. Mirrors `addToast`.
//
// TODO(gtk): adw.Toast creation + toast_overlay.addToast are out of scope. Kept
// as a stub with a faithful signature.
fn (mut self Window) add_toast(title string) {
	_ = title
}

// --- Properties -----------------------------------------------------------

// is_quick_terminal reports whether this terminal is a quick terminal. Mirrors
// `isQuickTerminal`.
pub fn (self &Window) is_quick_terminal() bool {
	return self.quick_terminal
}

// get_active_surface gets the currently active surface. See the
// "active-surface" property. This does not ref the value. Mirrors
// `getActiveSurface`.
//
// TODO(gtk): resolving the selected Tab and its active surface is out of scope
// (Tab is not translated). Returns none.
pub fn (self &Window) get_active_surface() ?&Surface {
	return none
}

// get_config returns the configuration for this window. The reference count is
// not increased. Mirrors `getConfig`.
pub fn (self &Window) get_config() ?&Config {
	if self.config == unsafe { nil } {
		return none
	}
	return self.config
}

// get_tab_view returns the tab view for this window. Mirrors `getTabView`.
pub fn (self &Window) get_tab_view() AdwTabView {
	return self.tab_view
}

// get_window_decoration returns the current window decoration value for this
// window. Mirrors `getWindowDecoration`.
pub fn (self &Window) get_window_decoration() configpkg.WindowDecoration {
	if self.has_window_decoration {
		return self.window_decoration
	}
	if self.config != unsafe { nil } {
		return self.config.get().window_decoration
	}
	return .auto
}

// toggle_window_decorations toggles the window decorations for this window.
// Mirrors `toggleWindowDecorations`.
pub fn (mut self Window) toggle_window_decorations() {
	if self.has_window_decoration {
		// Unset any previously set window decoration settings.
		self.unset_window_decoration()
		return
	}

	if self.config == unsafe { nil } {
		return
	}
	config := self.config.get()
	new_deco := match config.window_decoration {
		// Use auto when the decoration is initially none.
		.none_ { configpkg.WindowDecoration.auto }
		// Anything non-none to none.
		.auto, .client, .server { configpkg.WindowDecoration.none_ }
	}
	self.set_window_decoration(new_deco)
}

// set_window_decoration sets the window decoration override for this window.
// Mirrors the non-null branch of `setWindowDecoration`.
fn (mut self Window) set_window_decoration(new configpkg.WindowDecoration) {
	self.window_decoration = new
	self.has_window_decoration = true
	self.sync_apprt_window()
	self.sync_appearance()
}

// unset_window_decoration reverts the window decoration to the config default.
// Mirrors the null branch of `setWindowDecoration`.
fn (mut self Window) unset_window_decoration() {
	self.has_window_decoration = false
	self.sync_apprt_window()
	self.sync_appearance()
}

// get_needs_confirm_quit returns true if this window needs confirmation before
// quitting. Mirrors `getNeedsConfirmQuit`.
//
// TODO(gtk): iterating the tab pages and querying each Tab's
// getNeedsConfirmQuit is out of scope (Tab not translated). Returns false.
fn (self &Window) get_needs_confirm_quit() bool {
	return false
}

// is_fullscreen reports whether the window is fullscreen. Mirrors
// `isFullscreen`.
pub fn (self &Window) is_fullscreen() bool {
	return C.gtk_window_is_fullscreen(self.as_window()) != 0
}

// is_maximized reports whether the window is maximized. Mirrors `isMaximized`.
pub fn (self &Window) is_maximized() bool {
	return C.gtk_window_is_maximized(self.as_window()) != 0
}

// get_headerbar_visible computes whether the header bar should be visible.
// Mirrors `getHeaderbarVisible` — fully translated logic.
pub fn (self &Window) get_headerbar_visible() bool {
	// Never display the header bar when CSDs are disabled.
	if !self.winproto.client_side_decoration_enabled() {
		return false
	}

	// Never display the header bar as a quick terminal.
	if self.quick_terminal {
		return false
	}

	// If we're fullscreen we never show the header bar.
	if self.is_fullscreen() {
		return false
	}

	// The remainder needs a config.
	if self.config == unsafe { nil } {
		return true
	}

	// Conditionally disable the header bar when maximized and
	// gtk-titlebar-hide-when-maximized is set.
	if self.is_maximized() && self.config.gtk_titlebar_hide_when_maximized() {
		return false
	}

	return match self.config.gtk_titlebar_style() {
		// If the titlebar style is tabs never show the titlebar.
		.tabs { false }
		// If the titlebar style is native show the titlebar if configured to.
		.native { self.config.gtk_titlebar() }
	}
}

// get_tabs_autohide computes whether the tab bar should autohide. Mirrors
// `getTabsAutohide` — fully translated logic.
pub fn (self &Window) get_tabs_autohide() bool {
	if self.config == unsafe { nil } {
		return true
	}
	return match self.config.gtk_titlebar_style() {
		// If the titlebar style is tabs we cannot autohide.
		.tabs {
			false
		}
		.native {
			match self.config.window_show_tab_bar() {
				// Auto we always autohide... obviously.
				.auto { true }
				// Always we never autohide because we always show the tab bar.
				.always { false }
				// Never we autohide because it doesn't matter (getTabsVisible
				// returns false).
				.never { true }
			}
		}
	}
}

// get_tabs_visible computes whether the tab bar should be visible. Mirrors
// `getTabsVisible` — fully translated logic.
pub fn (self &Window) get_tabs_visible() bool {
	if self.config == unsafe { nil } {
		return true
	}
	return match self.config.gtk_titlebar_style() {
		.tabs {
			// Conditionally disable the tab bar when maximized, style is tabs,
			// and gtk-titlebar-hide-when-maximized is set.
			if self.is_maximized() && self.config.gtk_titlebar_hide_when_maximized() {
				false
			} else {
				// If the titlebar style is tabs the tab bar is always visible.
				true
			}
		}
		.native {
			match self.config.window_show_tab_bar() {
				.always, .auto { true }
				.never { false }
			}
		}
	}
}

// get_tabs_wide computes whether tabs should be wide. Mirrors `getTabsWide`.
pub fn (self &Window) get_tabs_wide() bool {
	if self.config == unsafe { nil } {
		return true
	}
	return self.config.gtk_wide_tabs()
}

// get_toolbar_style computes the AdwToolbarStyle from the config. Mirrors
// `getToolbarStyle`.
pub fn (self &Window) get_toolbar_style() AdwToolbarStyle {
	if self.config == unsafe { nil } {
		return .raised
	}
	return match self.config.gtk_toolbar_style() {
		.flat { AdwToolbarStyle.flat }
		.raised { AdwToolbarStyle.raised }
		.raised_border { AdwToolbarStyle.raised_border }
	}
}

// get_titlebar_style computes the GtkTitlebarStyle from the config. Mirrors
// `getTitlebarStyle`.
pub fn (self &Window) get_titlebar_style() configpkg.GtkTitlebarStyle {
	if self.config == unsafe { nil } {
		return .native
	}
	return self.config.gtk_titlebar_style()
}

// --- Fullscreen / maximize toggles ----------------------------------------

// toggle_fullscreen toggles the fullscreen state. Mirrors the body of
// `surfaceToggleFullscreen`.
pub fn (mut self Window) toggle_fullscreen() {
	if self.is_fullscreen() {
		self.unfullscreen()
	} else {
		self.fullscreen()
	}
	// We react to the changes in the prop_fullscreen callback.
}

// toggle_maximize toggles the maximized state. Mirrors the body of
// `surfaceToggleMaximize`.
pub fn (mut self Window) toggle_maximize() {
	if self.is_maximized() {
		self.unmaximize()
	} else {
		self.maximize()
	}
	// We react to the changes in the prop_maximized callback.
}

// --- Signal-handler-equivalents (config/prop reactions) -------------------

// window_realize initializes the window protocol logic once the window is
// realized, sets up resize notifications, and syncs appearance. Mirrors
// `windowRealize`.
pub fn (mut self Window) window_realize(mut app Application) {
	// Initialize our window protocol logic.
	mut app_wp := app.winproto()
	if wp := WinProtoWindow.init(mut app_wp, mut self.apprt_window) {
		self.winproto = wp
	} else {
		// log.warn: failed to initialize window protocol
		return
	}

	// TODO(gtk): connect gdk_surface "notify::width"/"notify::height" to
	// prop_gdk_surface_width/height. Requires the realized GdkSurface + GObject
	// signal connection; out of scope.

	// When we are realized we always setup our appearance since this calls
	// some winproto functions.
	self.sync_appearance()
}

// prop_config reacts to a config change: optionally toasts, then syncs
// appearance. Mirrors `propConfig`.
pub fn (mut self Window) prop_config() {
	// TODO(gtk): toast on config-reload requires app_notifications config
	// (absent in witty's core config) + add_toast (stubbed). Retained intent.
	self.sync_apprt_window()
	self.sync_appearance()
}

// prop_gdk_surface_resize reacts to a GdkSurface width/height change (X11 blur
// fix). Mirrors `propGdkSurfaceWidth`/`propGdkSurfaceHeight`.
pub fn (mut self Window) prop_gdk_surface_resize() {
	self.winproto.resize_event() or {
		// log.warn: winproto resize event failed
	}
}

// prop_is_active reacts to the window active state changing. Mirrors
// `propIsActive`.
pub fn (mut self Window) prop_is_active() {
	// Hide quick-terminal if set to autohide.
	if self.is_quick_terminal() {
		// TODO(gtk): quick-terminal-autohide config field is absent in witty's
		// core config; the autohide toggle is retained as intent.
		if C.gtk_window_is_active(self.as_window()) == 0 {
			// self.toggle_visibility() when quick-terminal-autohide is set
		}
	}

	// Don't change urgency if we're not the active window.
	if C.gtk_window_is_active(self.as_window()) == 0 {
		return
	}

	self.winproto.set_urgent(false) or {
		// log.warn: winproto failed to reset urgency
	}
}

// prop_fullscreened reacts to the fullscreen state changing. Mirrors
// `propFullscreened`.
pub fn (mut self Window) prop_fullscreened() {
	self.sync_appearance()
}

// prop_maximized reacts to the maximized state changing. Mirrors
// `propMaximized`.
pub fn (mut self Window) prop_maximized() {
	self.sync_appearance()
}

// prop_scale_factor reacts to a scale-factor change (X11 refresh). Mirrors
// `propScaleFactor`.
pub fn (mut self Window) prop_scale_factor() {
	self.winproto.sync_appearance() or {
		// log.warn: failed to sync appearance after scale factor update
	}
}

// prop_quick_terminal reacts to the quick-terminal property changing. Mirrors
// `propQuickTerminal`.
pub fn (mut self Window) prop_quick_terminal(mut app Application) {
	if self.surface_init {
		// log.warn: quick terminal property can't be changed after surfaces
		// have been initialized
		return
	}
	if self.quick_terminal {
		// Initialize the quick terminal at the app-layer.
		mut app_wp := app.winproto()
		app_wp.init_quick_terminal(mut self.apprt_window) or {
			// log.warn: failed to initialize quick terminal
			return
		}
	}
}

// --- Window close / lifecycle ---------------------------------------------

// window_close_request handles a window close request, showing a confirmation
// dialog if needed. Returns true to stop propagation (keep window open).
// Mirrors `windowCloseRequest`.
pub fn (mut self Window) window_close_request() bool {
	if self.get_needs_confirm_quit() {
		// TODO(gtk): show a CloseConfirmationDialog and connect its
		// "close-request" to close_confirmation_close. Out of scope; we
		// conservatively keep the window open (return true).
		return true
	}
	C.gtk_window_destroy(self.as_window())
	return false
}

// tab_view_n_pages reacts to the tab view's page count changing: if there are
// no pages left (and the tab overview is closed) we close the window. Mirrors
// `tabViewNPages` — fully translated logic.
pub fn (mut self Window) tab_view_n_pages() {
	if adw_tab_view_get_n_pages(self.tab_view) == 0 {
		// If the tab overview is open we don't close the window (abrupt UX,
		// and it fixes dragging out the last tab).
		if adw_tab_overview_get_open(self.tab_overview) != 0 {
			return
		}
		C.gtk_window_close(self.as_window())
	}
}

// --- Actions (stubbed callbacks) ------------------------------------------
// Mirrors the `action*` handlers. Each ultimately performs a binding action on
// the active surface (out of scope), so they are faithful stubs.

pub fn (mut self Window) action_close() {
	C.gtk_window_close(self.as_window())
}

pub fn (mut self Window) action_new_tab() {
	self.perform_binding_action(.new_tab)
}

pub fn (mut self Window) action_new_window() {
	self.perform_binding_action(.new_window)
}

pub fn (mut self Window) action_split_right() {
	self.perform_binding_action(.new_split_right)
}

pub fn (mut self Window) action_split_left() {
	self.perform_binding_action(.new_split_left)
}

pub fn (mut self Window) action_split_up() {
	self.perform_binding_action(.new_split_up)
}

pub fn (mut self Window) action_split_down() {
	self.perform_binding_action(.new_split_down)
}

pub fn (mut self Window) action_copy() {
	self.perform_binding_action(.copy_to_clipboard)
}

pub fn (mut self Window) action_paste() {
	self.perform_binding_action(.paste_from_clipboard)
}

pub fn (mut self Window) action_reset() {
	self.perform_binding_action(.reset)
}

pub fn (mut self Window) action_clear() {
	self.perform_binding_action(.clear_screen)
}

pub fn (mut self Window) action_ring_bell() {
	// TODO(gtk): bell-features config (system beep + attention urgency) is
	// absent in witty's core config. Retained as intent.
	if C.gtk_window_is_active(self.as_window()) != 0 {
		return
	}
	self.winproto.set_urgent(true) or {
		// log.warn: winproto failed to set urgency
	}
}

// BindingActionTag is a placeholder for the subset of `input.Binding.Action`
// tags the window's actions dispatch. TODO(gtk): the real actions carry data
// (close-tab mode, split direction, clipboard target); those are resolved at
// the core layer which is out of scope.
pub enum BindingActionTag {
	new_tab
	new_window
	new_split_right
	new_split_left
	new_split_up
	new_split_down
	copy_to_clipboard
	paste_from_clipboard
	reset
	clear_screen
}

// --- dispose / finalize ---------------------------------------------------

// dispose releases references held by the window. Mirrors `dispose` (minus the
// GObject template disposal + parent chaining).
pub fn (mut self Window) dispose() {
	self.command_palette.set(unsafe { nil })

	if self.config != unsafe { nil } {
		self.config.unref()
		self.config = unsafe { nil }
	}

	// TODO(gtk): tab_bindings.setSource(null) + gtk.Widget.disposeTemplate +
	// parent dispose chaining. Out of scope.
}

// finalize tears down the winproto state. Mirrors `finalize` (minus GObject
// parent chaining and the binding-group unref).
pub fn (mut self Window) finalize() {
	self.winproto.deinit()
	// TODO(gtk): tab_bindings.unref + parent finalize chaining. Out of scope.
}

// --- Upcasts / thin wrappers ----------------------------------------------

// as_widget returns this window upcast to a GtkWidget. Mirrors
// `self.as(gtk.Widget)`.
pub fn (self &Window) as_widget() GtkWidget {
	return GtkWidget(self.obj)
}

// as_window returns this window upcast to a GtkWindow. Mirrors
// `self.as(gtk.Window)`.
pub fn (self &Window) as_window() GtkWindow {
	return GtkWindow(self.obj)
}

// as_native returns this window upcast to a GtkNative. Mirrors
// `self.as(gtk.Native)`.
pub fn (self &Window) as_native() GtkNative {
	return GtkNative(self.obj)
}

// as_tab_bar_widget returns the tab bar upcast to a GtkWidget. Mirrors
// `priv.tab_bar.as(gtk.Widget)`.
fn (self &Window) as_tab_bar_widget() GtkWidget {
	return GtkWidget(self.tab_bar)
}

fn (self &Window) set_title(title string) {
	C.gtk_window_set_title(self.as_window(), &char(title.str))
}

fn (self &Window) set_icon_name(name string) {
	C.gtk_window_set_icon_name(self.as_window(), &char(name.str))
}

fn (self &Window) maximize() {
	C.gtk_window_maximize(self.as_window())
}

fn (self &Window) unmaximize() {
	C.gtk_window_unmaximize(self.as_window())
}

fn (self &Window) fullscreen() {
	C.gtk_window_fullscreen(self.as_window())
}

fn (self &Window) unfullscreen() {
	C.gtk_window_unfullscreen(self.as_window())
}

fn (self &Window) add_css_class(class string) {
	C.gtk_widget_add_css_class(self.as_widget(), &char(class.str))
}

fn (self &Window) remove_css_class(class string) {
	C.gtk_widget_remove_css_class(self.as_widget(), &char(class.str))
}

// b2i converts a bool to a C int (0/1), matching the `@intFromBool` idiom.
fn b2i(b bool) int {
	return if b { 1 } else { 0 }
}

// --- AdwTabView / AdwTabOverview / AdwToolbarView C bindings ---------------
// Wrapped so the tab-management arithmetic above stays readable. These are new
// (grep-verified not declared elsewhere).

fn C.adw_tab_view_get_n_pages(view AdwTabView) int
fn C.adw_tab_view_get_selected_page(view AdwTabView) AdwTabPage
fn C.adw_tab_view_set_selected_page(view AdwTabView, page AdwTabPage)
fn C.adw_tab_view_get_page_position(view AdwTabView, page AdwTabPage) int
fn C.adw_tab_view_get_nth_page(view AdwTabView, position int) AdwTabPage
fn C.adw_tab_view_get_page(view AdwTabView, child GtkWidget) AdwTabPage
fn C.adw_tab_view_append(view AdwTabView, child GtkWidget) AdwTabPage
fn C.adw_tab_view_insert(view AdwTabView, child GtkWidget, position int) AdwTabPage
fn C.adw_tab_view_reorder_page(view AdwTabView, page AdwTabPage, position int) int
fn C.adw_tab_overview_get_open(overview AdwTabOverview) int
fn C.adw_tab_overview_set_open(overview AdwTabOverview, open int)
fn C.adw_toolbar_view_remove(view AdwToolbarView, child GtkWidget)
fn C.adw_toolbar_view_add_top_bar(view AdwToolbarView, child GtkWidget)
fn C.adw_toolbar_view_add_bottom_bar(view AdwToolbarView, child GtkWidget)

fn adw_tab_view_get_n_pages(view AdwTabView) int {
	return C.adw_tab_view_get_n_pages(view)
}

fn adw_tab_view_get_selected_page(view AdwTabView) AdwTabPage {
	return C.adw_tab_view_get_selected_page(view)
}

fn adw_tab_view_set_selected_page(view AdwTabView, page AdwTabPage) {
	C.adw_tab_view_set_selected_page(view, page)
}

fn adw_tab_view_get_page_position(view AdwTabView, page AdwTabPage) int {
	return C.adw_tab_view_get_page_position(view, page)
}

fn adw_tab_view_get_nth_page(view AdwTabView, position int) AdwTabPage {
	return C.adw_tab_view_get_nth_page(view, position)
}

fn adw_tab_view_get_page(view AdwTabView, child GtkWidget) AdwTabPage {
	return C.adw_tab_view_get_page(view, child)
}

fn adw_tab_view_append(view AdwTabView, child GtkWidget) AdwTabPage {
	return C.adw_tab_view_append(view, child)
}

fn adw_tab_view_insert(view AdwTabView, child GtkWidget, position int) AdwTabPage {
	return C.adw_tab_view_insert(view, child, position)
}

fn adw_tab_view_reorder_page(view AdwTabView, page AdwTabPage, position int) int {
	return C.adw_tab_view_reorder_page(view, page, position)
}

fn adw_tab_overview_get_open(overview AdwTabOverview) int {
	return C.adw_tab_overview_get_open(overview)
}

fn adw_tab_overview_set_open(overview AdwTabOverview, open int) {
	C.adw_tab_overview_set_open(overview, open)
}

fn adw_toolbar_view_remove(view AdwToolbarView, child GtkWidget) {
	C.adw_toolbar_view_remove(view, child)
}

fn adw_toolbar_view_add_top_bar(view AdwToolbarView, child GtkWidget) {
	C.adw_toolbar_view_add_top_bar(view, child)
}

fn adw_toolbar_view_add_bottom_bar(view AdwToolbarView, child GtkWidget) {
	C.adw_toolbar_view_add_bottom_bar(view, child)
}
