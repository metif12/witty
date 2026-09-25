module gtk

// winproto_wayland_linux.v - Wayland window-protocol backend for the GTK apprt.
//
// Translated from ghostty/src/apprt/gtk/winproto/wayland.zig.
//
// Implements:
//   - Application-wide Wayland state (wl_display, registry-bound globals).
//   - KDE background blur via org_kde_kwin_blur_manager / org_kde_kwin_blur.
//   - Decoration mode (client/server/auto) via
//     org_kde_kwin_server_decoration_manager.
//   - Window urgency via xdg_activation_v1.
//   - Quick-terminal layer-shell integration and KDE slide animation.
//
// SCOPE NOTE: In ghostty the Wayland protocol proxies (wl_registry, the
// org_kde_kwin_* interfaces, xdg_activation_v1, etc.) are *generated* by the
// `wayland` zig package from protocol XML. The generated KDE/xdg proxy layer
// is hand-expanded below; gtk4-layer-shell is called through its public C ABI.
// We therefore:
//   - declare the base libwayland-client entry points we genuinely need
//     (wl_display registry + roundtrip),
//   - model each generated protocol proxy as an opaque `voidptr`,
//   - keep the *decision logic* (getDecorationMode, blur-token lifecycle,
//     urgency lifecycle) faithful and delegate actual requests to the thin
//     protocol wrappers below.

import input
import configpkg

#flag linux -lwayland-client

#pkgconfig gtk4-layer-shell-0

#include <gtk4-layer-shell.h>

#include <wayland-client.h>

#include <gdk/wayland/gdkwayland.h>

#include "wayland_shims.h"

// --- Opaque Wayland handle aliases -----------------------------------------

// WlDisplay is an opaque `wl_display *`.
pub type WlDisplay = voidptr

// WlRegistry is an opaque `wl_registry *`.
pub type WlRegistry = voidptr

// WlSurface is an opaque `wl_surface *`.
pub type WlSurface = voidptr

// The KDE-KWin + xdg protocol proxies, all opaque. These correspond to the
// generated `org.KdeKwin*` / `xdg.*` types in ghostty.
pub type KdeKwinBlurManager = voidptr

pub type KdeKwinBlur = voidptr

pub type KdeKwinServerDecorationManager = voidptr

pub type KdeKwinServerDecoration = voidptr

pub type KdeKwinSlideManager = voidptr

pub type KdeKwinSlide = voidptr

pub type XdgActivationV1 = voidptr

pub type XdgActivationTokenV1 = voidptr

// --- GDK-Wayland bridge C declarations -------------------------------------
// From gdk/wayland/gdkwayland.h. We only need to detect a Wayland display and
// pull out the underlying wl_display / wl_surface.

fn C.GDK_IS_WAYLAND_DISPLAY(display GdkDisplay) int

fn C.gdk_wayland_display_get_wl_display(display GdkDisplay) WlDisplay

fn C.gdk_wayland_surface_get_wl_surface(surface GdkSurface) WlSurface

// --- libwayland-client C declarations --------------------------------------

fn C.wl_display_get_registry(display WlDisplay) WlRegistry

fn C.wl_display_roundtrip(display WlDisplay) int

// Hand-expanded generated Wayland bindings in wayland_shims.h.
fn C.witty_wayland_registry_add_listener(registry WlRegistry, global_cb GCallback, remove_cb GCallback, data voidptr) voidptr

fn C.witty_wayland_registry_bind(registry WlRegistry, name u32, kind u32, version u32) voidptr

fn C.witty_kde_decoration_add_listener(manager voidptr, callback GCallback, data voidptr) voidptr

fn C.witty_xdg_activation_token_add_listener(token voidptr, callback GCallback, data voidptr) voidptr

fn C.witty_wayland_listener_free(listener voidptr)

fn C.witty_wayland_proxy_get_id(proxy voidptr) u32

fn C.witty_wayland_proxy_destroy(proxy voidptr)

fn C.witty_kde_decoration_create(manager voidptr, surface voidptr) voidptr

fn C.witty_kde_decoration_request_mode(decoration voidptr, mode u32)

fn C.witty_kde_decoration_release(decoration voidptr)

fn C.witty_kde_blur_create(manager voidptr, surface voidptr) voidptr

fn C.witty_kde_blur_unset(manager voidptr, surface voidptr)

fn C.witty_kde_blur_commit(blur voidptr)

fn C.witty_kde_blur_release(blur voidptr)

fn C.witty_kde_slide_create(manager voidptr, surface voidptr) voidptr

fn C.witty_kde_slide_commit(slide voidptr)

fn C.witty_kde_slide_set_location(slide voidptr, location u32)

fn C.witty_kde_slide_release(slide voidptr)

fn C.witty_xdg_activation_get_token(activation voidptr) voidptr

fn C.witty_xdg_activation_token_set_surface(token voidptr, surface voidptr)

fn C.witty_xdg_activation_token_commit(token voidptr)

fn C.witty_xdg_activation_token_destroy(token voidptr)

fn C.witty_xdg_activation_activate(activation voidptr, token &char, surface voidptr)

// gtk4-layer-shell public C API.
fn C.gtk_layer_is_supported() int

fn C.gtk_layer_get_protocol_version() u32

fn C.gtk_layer_get_major_version() u32

fn C.gtk_layer_get_minor_version() u32

fn C.gtk_layer_get_micro_version() u32

fn C.gtk_layer_init_for_window(window GtkWindow)

fn C.gtk_layer_set_layer(window GtkWindow, layer u32)

fn C.gtk_layer_set_anchor(window GtkWindow, edge u32, anchor_to_edge int)

fn C.gtk_layer_set_margin(window GtkWindow, edge u32, margin_size int)

fn C.gtk_layer_set_keyboard_mode(window GtkWindow, mode u32)

fn C.gtk_layer_set_namespace(window GtkWindow, name &char)

fn C.gdk_monitor_get_geometry(monitor voidptr, geometry &C.GdkRectangle)

enum LayerShellLayer as u32 {
	background
	bottom
	top
	overlay
}

enum LayerShellEdge as u32 {
	left
	right
	top
	bottom
}

enum LayerShellKeyboardMode as u32 {
	none_
	exclusive
	on_demand
}

enum WaylandInterfaceKind as u32 {
	kde_blur_manager
	kde_decoration_manager
	kde_slide_manager
	xdg_activation
}

enum KdeSlideLocation as u32 {
	left
	top
	right
	bottom
}

// KdeKwinServerDecorationMode mirrors
// `org.KdeKwinServerDecorationManager.Mode`. Values match the KDE protocol:
// None=0, Client=1, Server=2.
pub enum KdeKwinServerDecorationMode as u32 {
	none_  = 0
	client = 1
	server = 2
}

// --- App -------------------------------------------------------------------

// WaylandContext holds the registry-bound global objects. Mirrors
// wayland.zig's `App.Context`. A stable pointer is kept so listener callbacks
// have a valid target.
pub struct WaylandContext {
pub mut:
	kde_blur_manager       KdeKwinBlurManager = unsafe { nil }
	kde_decoration_manager KdeKwinServerDecorationManager = unsafe { nil }
	kde_slide_manager      KdeKwinSlideManager = unsafe { nil }
	// The compositor's default decoration mode, learned from the decoration
	// manager's default_mode event. `none` until known.
	default_deco_mode ?KdeKwinServerDecorationMode
	xdg_activation    XdgActivationV1 = unsafe { nil }
	// Whether the xdg_wm_dialog_v1 protocol is present (affects quick terminal
	// with old gtk4-layer-shell). See wayland.zig for the gory details.
	xdg_wm_dialog_present bool
	registry_listener     voidptr = unsafe { nil }
	decoration_listener   voidptr = unsafe { nil }
}

// WaylandApp is the application-wide Wayland state. Mirrors wayland.zig's
// `App`.
pub struct WaylandApp {
pub mut:
	display WlDisplay = unsafe { nil }
	context &WaylandContext = unsafe { nil }
}

// WaylandApp.init sets up the Wayland backend for the given display, or returns
// `none` if the display is not Wayland. Mirrors `wayland.App.init`.
//
// Ghostty returns `!?App`; V has no Result-of-Option, so we return
// `?WaylandApp`: `none` means "not a Wayland display" OR "setup failed"
// (ghostty's error.NoWaylandDisplay / error.RoundtripFailed). Hard failures are
// logged and mapped to `none` so the app degrades to the no-op backend.
pub fn WaylandApp.init(gdk_display GdkDisplay, app_id string, config &configpkg.Config) ?WaylandApp {
	_ = app_id
	_ = config

	if C.GDK_IS_WAYLAND_DISPLAY(gdk_display) == 0 {
		return none
	}

	display := C.gdk_wayland_display_get_wl_display(gdk_display)
	if display == unsafe { nil } {
		eprintln('no wayland display')
		return none
	}

	// Create our context for callbacks so we have a stable pointer.
	mut context := &WaylandContext{}

	// Get the registry and bind the globals we need, then round-trip so the
	// server delivers the global advertisements.
	registry := C.wl_display_get_registry(display)
	registry_set_listener(registry, mut context)
	if C.wl_display_roundtrip(display) < 0 {
		eprintln('wayland roundtrip failed')
		return none
	}

	// A second round-trip to learn the default decoration mode.
	if context.kde_decoration_manager != unsafe { nil } {
		deco_manager_set_listener(context.kde_decoration_manager, mut context)
		if C.wl_display_roundtrip(display) < 0 {
			eprintln('wayland roundtrip failed')
			return none
		}
	}

	return WaylandApp{
		display: display
		context: context
	}
}

// deinit mirrors `wayland.App.deinit`. In ghostty this frees the heap-allocated
// context; V's GC owns it here.
pub fn (mut self WaylandApp) deinit() {
	if isnil(self.context) {
		return
	}
	if !isnil(self.context.registry_listener) {
		C.witty_wayland_listener_free(self.context.registry_listener)
		self.context.registry_listener = unsafe { nil }
	}
	if !isnil(self.context.decoration_listener) {
		C.witty_wayland_listener_free(self.context.decoration_listener)
		self.context.decoration_listener = unsafe { nil }
	}
}

// event_mods mirrors `wayland.App.eventMods`. Wayland has no equivalent of the
// X11 XKB peek, so it always defers to the standard GDK translation.
pub fn (mut self WaylandApp) event_mods(device GdkDevice, gtk_mods u32) ?input.Mods {
	_ = device
	_ = gtk_mods
	return none
}

// supports_quick_terminal mirrors `wayland.App.supportsQuickTerminal`.
pub fn (self WaylandApp) supports_quick_terminal() bool {
	if !layer_shell_is_supported() {
		eprintln('your compositor does not support the wlr-layer-shell protocol; disabling quick terminal')
		return false
	}
	if self.context.xdg_wm_dialog_present && layer_shell_version_less_than(1, 0, 4) {
		eprintln('the version of gtk4-layer-shell installed on your system is too old (must be 1.0.4 or newer); disabling quick terminal')
		return false
	}
	return true
}

// init_quick_terminal mirrors `wayland.App.initQuickTerminal`. Initializes
// gtk4-layer-shell for the window.
pub fn (mut self WaylandApp) init_quick_terminal(apprt_window &ApprtWindow) ! {
	layer_shell_init_for_window(apprt_window.as_window())
}

// --- Window ----------------------------------------------------------------

// WaylandWindow is the per-window (wl_surface) Wayland state. Mirrors
// wayland.zig's `Window`.
pub struct WaylandWindow {
pub mut:
	apprt_window &ApprtWindow = unsafe { nil }

	// The Wayland surface for this window.
	surface WlSurface = unsafe { nil }

	// The context from the app where we load our Wayland interfaces.
	app_context &WaylandContext = unsafe { nil }

	// A token that, when present, indicates the window is blurred.
	blur_token KdeKwinBlur = unsafe { nil }

	// Object controlling the decoration mode of the window.
	decoration KdeKwinServerDecoration = unsafe { nil }

	// Object controlling slide animations of the quick terminal.
	slide KdeKwinSlide = unsafe { nil }

	// Object denoting an in-flight attention request (urgency).
	activation_token    XdgActivationTokenV1 = unsafe { nil }
	activation_listener voidptr = unsafe { nil }
}

// WaylandWindow.init mirrors `wayland.Window.init`.
pub fn WaylandWindow.init(mut app WaylandApp, mut apprt_window ApprtWindow) !WaylandWindow {
	gdk_surface := apprt_window.get_surface() or { return error('not a wayland surface') }

	wl_surface := C.gdk_wayland_surface_get_wl_surface(gdk_surface)
	if wl_surface == unsafe { nil } {
		return error('no wayland surface')
	}

	// Get the decoration object so we can control CSD vs SSD for this surface.
	mut deco := KdeKwinServerDecoration(unsafe { nil })
	if app.context.kde_decoration_manager != unsafe { nil } {
		deco = kde_decoration_manager_create(app.context.kde_decoration_manager, wl_surface) or {
			eprintln('could not create decoration object=${err}')
			KdeKwinServerDecoration(unsafe { nil })
		}
	}

	if apprt_window.is_quick_terminal() {
		C.g_signal_connect_data(gdk_surface, c'enter-monitor', GCallback(voidptr(wayland_entered_monitor_cb)), voidptr(&apprt_window), unsafe { nil }, 0)
	}

	return WaylandWindow{
		apprt_window: &apprt_window
		surface: wl_surface
		app_context: app.context
		decoration: deco
	}
}

// deinit mirrors `wayland.Window.deinit`. Releases any protocol objects.
pub fn (self WaylandWindow) deinit() {
	if self.blur_token != unsafe { nil } {
		kde_blur_release(self.blur_token)
	}
	if self.decoration != unsafe { nil } {
		kde_decoration_release(self.decoration)
	}
	if self.slide != unsafe { nil } {
		kde_slide_release(self.slide)
	}
}

// resize_event mirrors `wayland.Window.resizeEvent` (no-op on Wayland).
pub fn (mut self WaylandWindow) resize_event() ! {}

// sync_appearance mirrors `wayland.Window.syncAppearance`.
pub fn (mut self WaylandWindow) sync_appearance() ! {
	self.sync_blur() or { eprintln('failed to sync blur=${err}') }
	self.sync_decoration() or { eprintln('failed to sync decoration=${err}') }

	if self.apprt_window.is_quick_terminal() {
		self.sync_quick_terminal() or {
			eprintln('failed to sync quick terminal appearance=${err}')
		}
	}
}

// client_side_decoration_enabled mirrors
// `wayland.Window.clientSideDecorationEnabled`.
pub fn (self WaylandWindow) client_side_decoration_enabled() bool {
	return match self.get_decoration_mode() {
		.client { true }
		// If we support SSDs, don't enable CSDs when SSDs are preferred. But if
		// we don't support SSDs (e.g. GNOME) enable CSDs even if SSDs preferred.
		.server { self.app_context.kde_decoration_manager == unsafe { nil } }
		.none_ { false }
	}
}

// add_subprocess_env mirrors `wayland.Window.addSubprocessEnv` (no-op).
pub fn (mut self WaylandWindow) add_subprocess_env(mut env map[string]string) ! {
	_ = env
}

// set_urgent mirrors `wayland.Window.setUrgent`. Uses xdg_activation to request
// (or clear) attention.
pub fn (mut self WaylandWindow) set_urgent(urgent bool) ! {
	activation := self.app_context.xdg_activation
	if activation == unsafe { nil } {
		return
	}

	// If there's already a token, destroy and unset it.
	if self.activation_token != unsafe { nil } {
		xdg_activation_token_destroy(self.activation_token)
		self.activation_token = unsafe { nil }
		if !isnil(self.activation_listener) {
			C.witty_wayland_listener_free(self.activation_listener)
			self.activation_listener = unsafe { nil }
		}
	}

	if urgent {
		token := xdg_activation_get_token(activation)!
		xdg_activation_token_set_surface(token, self.surface)
		activation_token_set_listener(token, mut self)
		xdg_activation_token_commit(token)
		self.activation_token = token
	}
}

// sync_blur updates the blur state of the window. Mirrors
// `wayland.Window.syncBlur`.
fn (mut self WaylandWindow) sync_blur() ! {
	manager := self.app_context.kde_blur_manager
	if manager == unsafe { nil } {
		return
	}
	config_object := self.apprt_window.get_config() or { return }
	config := config_object.get()
	blur := config.background_blur

	if self.blur_token != unsafe { nil } {
		// Only release when transitioning blurred -> not blurred.
		if !blur_enabled(blur) {
			kde_blur_manager_unset(manager, self.surface)
			kde_blur_release(self.blur_token)
			self.blur_token = unsafe { nil }
		}
	} else {
		// Only acquire when transitioning not blurred -> blurred.
		if blur_enabled(blur) {
			tok := kde_blur_manager_create(manager, self.surface)!
			kde_blur_commit(tok)
			self.blur_token = tok
		}
	}
}

// sync_decoration requests the current decoration mode. Mirrors
// `wayland.Window.syncDecoration`.
fn (mut self WaylandWindow) sync_decoration() ! {
	deco := self.decoration
	if deco == unsafe { nil } {
		return
	}
	// The protocol requests uint, so convert from the enum.
	kde_decoration_request_mode(deco, u32(int(self.get_decoration_mode())))
}

// get_decoration_mode maps the window's decoration config to a KDE decoration
// mode. Mirrors `wayland.Window.getDecorationMode`.
fn (self WaylandWindow) get_decoration_mode() KdeKwinServerDecorationMode {
	return match self.apprt_window.get_window_decoration() {
		.auto { self.app_context.default_deco_mode or { KdeKwinServerDecorationMode.client } }
		.client { .client }
		.server { .server }
		.none_ { .none_ }
	}
}

// sync_quick_terminal configures gtk4-layer-shell + KDE slide for the quick
// terminal. Mirrors `wayland.Window.syncQuickTerminal`.
fn (mut self WaylandWindow) sync_quick_terminal() ! {
	window := self.apprt_window.as_window()
	config_object := self.apprt_window.get_config() or { return }
	config := config_object.get()

	layer_shell_set_layer(window, match config.gtk_quick_terminal_layer {
		.overlay { .overlay }
		.top { .top }
		.bottom { .bottom }
		.background { .background }
	})
	layer_shell_set_namespace(window, config.gtk_quick_terminal_namespace)

	keyboard_mode := match config.quick_terminal_keyboard_interactivity {
		.none_ { LayerShellKeyboardMode.none_ }
		.on_demand {
			if C.gtk_layer_get_protocol_version() < 4 {
				eprintln('your compositor does not support on-demand keyboard access; falling back to exclusive access')
				LayerShellKeyboardMode.exclusive
			} else {
				LayerShellKeyboardMode.on_demand
			}
		}
		.exclusive { LayerShellKeyboardMode.exclusive }
	}
	layer_shell_set_keyboard_mode(window, keyboard_mode)

	anchored_edge := match config.quick_terminal_position {
		.left { ?LayerShellEdge(LayerShellEdge.left) }
		.right { ?LayerShellEdge(LayerShellEdge.right) }
		.top { ?LayerShellEdge(LayerShellEdge.top) }
		.bottom { ?LayerShellEdge(LayerShellEdge.bottom) }
		.center { none }
	}
	for edge in [LayerShellEdge.left, .right, .top, .bottom] {
		if anchored := anchored_edge {
			if edge == anchored {
				layer_shell_set_margin(window, edge, 0)
				layer_shell_set_anchor(window, edge, true)
				continue
			}
		}
		layer_shell_set_margin(window, edge, 20)
		layer_shell_set_anchor(window, edge, false)
	}

	if self.slide != unsafe { nil } {
		kde_slide_release(self.slide)
		self.slide = unsafe { nil }
	}
	if anchored := anchored_edge {
		manager := self.app_context.kde_slide_manager
		if manager != unsafe { nil } {
			slide := kde_slide_manager_create(manager, self.surface) or {
				eprintln('could not create slide object=${err}')
				return
			}
			location := match anchored {
				.left { KdeSlideLocation.left }
				.right { KdeSlideLocation.right }
				.top { KdeSlideLocation.top }
				.bottom { KdeSlideLocation.bottom }
			}
			kde_slide_set_location(slide, u32(location))
			kde_slide_commit(slide)
			self.slide = slide
		}
	}
}

fn wayland_entered_monitor_cb(surface GdkSurface, monitor voidptr, user_data voidptr) {
	_ = surface
	if isnil(monitor) || isnil(user_data) {
		return
	}
	apprt_window := unsafe { &ApprtWindow(user_data) }
	config_object := apprt_window.get_config() or { return }
	config := config_object.get()
	mut monitor_size := C.GdkRectangle{}
	C.gdk_monitor_get_geometry(monitor, &monitor_size)
	dims := config.quick_terminal_size.calculate(config.quick_terminal_position, configpkg.QuickTerminalDimensions{
		width: u32(monitor_size.width)
		height: u32(monitor_size.height)
	})
	C.gtk_window_set_default_size(apprt_window.as_window(), int(dims.width), int(dims.height))
}

// --- Listeners -------------------------------------------------------------

// registry_set_listener installs the registry global/global_remove listener
// that binds the KDE-KWin + xdg_activation globals into the context.
fn registry_set_listener(registry WlRegistry, mut context WaylandContext) {
	context.registry_listener = C.witty_wayland_registry_add_listener(registry, GCallback(voidptr(wayland_registry_global_cb)), GCallback(voidptr(wayland_registry_remove_cb)), voidptr(context))
}

fn wayland_registry_global_cb(context_ptr voidptr, registry WlRegistry, name u32, interface_ptr &char, version u32) {
	if isnil(context_ptr) || isnil(interface_ptr) {
		return
	}
	mut context := unsafe { &WaylandContext(context_ptr) }
	interface_name := unsafe { cstring_to_vstring(interface_ptr) }
	if interface_name == 'xdg_wm_dialog_v1' {
		context.xdg_wm_dialog_present = true
		return
	}
	kind := match interface_name {
		'org_kde_kwin_blur_manager' { WaylandInterfaceKind.kde_blur_manager }
		'org_kde_kwin_server_decoration_manager' { WaylandInterfaceKind.kde_decoration_manager }
		'org_kde_kwin_slide_manager' { WaylandInterfaceKind.kde_slide_manager }
		'xdg_activation_v1' { WaylandInterfaceKind.xdg_activation }
		else {
			return
		}
	}
	proxy := C.witty_wayland_registry_bind(registry, name, u32(kind), version)
	if isnil(proxy) {
		eprintln('error binding Wayland interface ${interface_name}')
		return
	}
	match kind {
		.kde_blur_manager {
			context.kde_blur_manager = proxy
		}
		.kde_decoration_manager {
			context.kde_decoration_manager = proxy
		}
		.kde_slide_manager {
			context.kde_slide_manager = proxy
		}
		.xdg_activation {
			context.xdg_activation = proxy
		}
	}
}

fn wayland_registry_remove_cb(context_ptr voidptr, registry WlRegistry, name u32) {
	_ = registry
	if isnil(context_ptr) {
		return
	}
	mut context := unsafe { &WaylandContext(context_ptr) }
	if context.kde_blur_manager == unsafe { nil } {
		return
	}
	if C.witty_wayland_proxy_get_id(context.kde_blur_manager) == name {
		C.witty_wayland_proxy_destroy(context.kde_blur_manager)
		context.kde_blur_manager = unsafe { nil }
		return
	}
	if context.kde_decoration_manager == unsafe { nil } {
		return
	}
	if C.witty_wayland_proxy_get_id(context.kde_decoration_manager) == name {
		C.witty_wayland_proxy_destroy(context.kde_decoration_manager)
		context.kde_decoration_manager = unsafe { nil }
		return
	}
	if context.kde_slide_manager == unsafe { nil } {
		return
	}
	if C.witty_wayland_proxy_get_id(context.kde_slide_manager) == name {
		C.witty_wayland_proxy_destroy(context.kde_slide_manager)
		context.kde_slide_manager = unsafe { nil }
		return
	}
	if context.xdg_activation == unsafe { nil } {
		return
	}
	if C.witty_wayland_proxy_get_id(context.xdg_activation) == name {
		C.witty_wayland_proxy_destroy(context.xdg_activation)
		context.xdg_activation = unsafe { nil }
	}
}

// deco_manager_set_listener installs the decoration-manager listener that
// records the compositor's default decoration mode.
fn deco_manager_set_listener(manager KdeKwinServerDecorationManager, mut context WaylandContext) {
	context.decoration_listener = C.witty_kde_decoration_add_listener(manager, GCallback(voidptr(wayland_decoration_default_mode_cb)), voidptr(context))
}

fn wayland_decoration_default_mode_cb(context_ptr voidptr, manager KdeKwinServerDecorationManager, mode u32) {
	_ = manager
	if isnil(context_ptr) || mode > u32(KdeKwinServerDecorationMode.server) {
		return
	}
	mut context := unsafe { &WaylandContext(context_ptr) }
	context.default_deco_mode = unsafe { KdeKwinServerDecorationMode(mode) }
}

// activation_token_set_listener installs the activation-token `done` listener
// that activates the surface once the token is ready.
fn activation_token_set_listener(token XdgActivationTokenV1, mut window WaylandWindow) {
	window.activation_listener = C.witty_xdg_activation_token_add_listener(token, GCallback(voidptr(wayland_activation_done_cb)), voidptr(&window))
}

fn wayland_activation_done_cb(window_ptr voidptr, token XdgActivationTokenV1, token_value &char) {
	if isnil(window_ptr) || isnil(token_value) {
		return
	}
	mut window := unsafe { &WaylandWindow(window_ptr) }
	activation := window.app_context.xdg_activation
	current := window.activation_token
	if activation == unsafe { nil } || current == unsafe { nil }
		|| C.witty_wayland_proxy_get_id(token) != C.witty_wayland_proxy_get_id(current) {
		eprintln('received event for unknown activation token; ignoring')
		return
	}
	C.witty_xdg_activation_activate(activation, token_value, window.surface)
	xdg_activation_token_destroy(token)
	window.activation_token = unsafe { nil }
	if !isnil(window.activation_listener) {
		C.witty_wayland_listener_free(window.activation_listener)
		window.activation_listener = unsafe { nil }
	}
}

// --- Thin protocol-proxy wrappers ------------------------------------------

fn kde_decoration_manager_create(mgr KdeKwinServerDecorationManager, surface WlSurface) !KdeKwinServerDecoration {
	result := C.witty_kde_decoration_create(mgr, surface)
	if isnil(result) {
		return error('decoration manager create failed')
	}
	return result
}

fn kde_decoration_request_mode(deco KdeKwinServerDecoration, mode u32) {
	C.witty_kde_decoration_request_mode(deco, mode)
}

fn kde_decoration_release(deco KdeKwinServerDecoration) {
	C.witty_kde_decoration_release(deco)
}

fn kde_blur_manager_create(mgr KdeKwinBlurManager, surface WlSurface) !KdeKwinBlur {
	result := C.witty_kde_blur_create(mgr, surface)
	if isnil(result) {
		return error('blur manager create failed')
	}
	return result
}

fn kde_blur_manager_unset(mgr KdeKwinBlurManager, surface WlSurface) {
	C.witty_kde_blur_unset(mgr, surface)
}

fn kde_blur_commit(blur KdeKwinBlur) {
	C.witty_kde_blur_commit(blur)
}

fn kde_blur_release(blur KdeKwinBlur) {
	C.witty_kde_blur_release(blur)
}

fn kde_slide_release(slide KdeKwinSlide) {
	C.witty_kde_slide_release(slide)
}

fn kde_slide_manager_create(manager KdeKwinSlideManager, surface WlSurface) !KdeKwinSlide {
	result := C.witty_kde_slide_create(manager, surface)
	if isnil(result) {
		return error('slide manager create failed')
	}
	return result
}

fn kde_slide_set_location(slide KdeKwinSlide, location u32) {
	C.witty_kde_slide_set_location(slide, location)
}

fn kde_slide_commit(slide KdeKwinSlide) {
	C.witty_kde_slide_commit(slide)
}

fn xdg_activation_get_token(activation XdgActivationV1) !XdgActivationTokenV1 {
	result := C.witty_xdg_activation_get_token(activation)
	if isnil(result) {
		return error('xdg activation token create failed')
	}
	return result
}

fn xdg_activation_token_set_surface(token XdgActivationTokenV1, surface WlSurface) {
	C.witty_xdg_activation_token_set_surface(token, surface)
}

fn xdg_activation_token_commit(token XdgActivationTokenV1) {
	C.witty_xdg_activation_token_commit(token)
}

fn xdg_activation_token_destroy(token XdgActivationTokenV1) {
	C.witty_xdg_activation_token_destroy(token)
}

// --- gtk4-layer-shell wrappers ---------------------------------------------

fn layer_shell_is_supported() bool {
	return C.gtk_layer_is_supported() != 0
}

fn layer_shell_init_for_window(window GtkWindow) {
	C.gtk_layer_init_for_window(window)
}

fn layer_shell_version_less_than(major u32, minor u32, micro u32) bool {
	actual_major := C.gtk_layer_get_major_version()
	actual_minor := C.gtk_layer_get_minor_version()
	actual_micro := C.gtk_layer_get_micro_version()
	return actual_major < major || (actual_major == major && (actual_minor < minor
		|| (actual_minor == minor && actual_micro < micro)))
}

fn layer_shell_set_layer(window GtkWindow, layer LayerShellLayer) {
	C.gtk_layer_set_layer(window, u32(layer))
}

fn layer_shell_set_namespace(window GtkWindow, namespace string) {
	C.gtk_layer_set_namespace(window, &char(namespace.str))
}

fn layer_shell_set_keyboard_mode(window GtkWindow, mode LayerShellKeyboardMode) {
	C.gtk_layer_set_keyboard_mode(window, u32(mode))
}

fn layer_shell_set_anchor(window GtkWindow, edge LayerShellEdge, anchored bool) {
	C.gtk_layer_set_anchor(window, u32(edge), b2i(anchored))
}

fn layer_shell_set_margin(window GtkWindow, edge LayerShellEdge, margin int) {
	C.gtk_layer_set_margin(window, u32(edge), margin)
}
