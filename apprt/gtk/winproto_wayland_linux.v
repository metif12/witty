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
//   - Quick-terminal slide + layer-shell integration (stubbed; see below).
//
// SCOPE NOTE: In ghostty the Wayland protocol proxies (wl_registry, the
// org_kde_kwin_* interfaces, xdg_activation_v1, etc.) are *generated* by the
// `wayland` zig package from the protocol XML, and gtk4-layer-shell is an
// external library. Those code generators / libraries are out of scope for
// this translation. We therefore:
//   - declare the base libwayland-client entry points we genuinely need
//     (wl_display registry + roundtrip),
//   - model each generated protocol proxy as an opaque `voidptr`,
//   - keep the *decision logic* (getDecorationMode, blur-token lifecycle,
//     urgency lifecycle) faithful, delegating the actual proxy requests to
//     thin `// TODO(gtk)` wrapper fns that will bind to the generated proxies
//     once the wayland protocol codegen is ported.

import input
import configpkg

#flag linux -lwayland-client
#include <wayland-client.h>

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

// KdeKwinServerDecorationMode mirrors
// `org.KdeKwinServerDecorationManager.Mode`. Values match the KDE protocol:
// None=0, Client=1, Server=2.
pub enum KdeKwinServerDecorationMode {
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
	kde_blur_manager      KdeKwinBlurManager            = unsafe { nil }
	kde_decoration_manager KdeKwinServerDecorationManager = unsafe { nil }
	kde_slide_manager     KdeKwinSlideManager           = unsafe { nil }
	// The compositor's default decoration mode, learned from the decoration
	// manager's default_mode event. `none` until known.
	default_deco_mode     ?KdeKwinServerDecorationMode
	xdg_activation        XdgActivationV1               = unsafe { nil }
	// Whether the xdg_wm_dialog_v1 protocol is present (affects quick terminal
	// with old gtk4-layer-shell). See wayland.zig for the gory details.
	xdg_wm_dialog_present bool
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
	context := &WaylandContext{}

	// Get the registry and bind the globals we need, then round-trip so the
	// server delivers the global advertisements.
	registry := C.wl_display_get_registry(display)
	registry_set_listener(registry, context)
	if C.wl_display_roundtrip(display) < 0 {
		eprintln('wayland roundtrip failed')
		return none
	}

	// A second round-trip to learn the default decoration mode.
	if context.kde_decoration_manager != unsafe { nil } {
		deco_manager_set_listener(context.kde_decoration_manager, context)
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
pub fn (mut self WaylandApp) deinit() {}

// event_mods mirrors `wayland.App.eventMods`. Wayland has no equivalent of the
// X11 XKB peek, so it always defers to the standard GDK translation.
pub fn (mut self WaylandApp) event_mods(device GdkDevice, gtk_mods u32) ?input.Mods {
	_ = device
	_ = gtk_mods
	return none
}

// supports_quick_terminal mirrors `wayland.App.supportsQuickTerminal`.
pub fn (self WaylandApp) supports_quick_terminal() bool {
	// TODO(gtk): requires gtk4-layer-shell (layer_shell.isSupported() plus the
	// xdg_wm_dialog_present / library-version guard). That library is out of
	// scope for this translation. Reported unsupported until it is wired up.
	if !layer_shell_is_supported() {
		return false
	}
	return true
}

// init_quick_terminal mirrors `wayland.App.initQuickTerminal`. Initializes
// gtk4-layer-shell for the window.
pub fn (mut self WaylandApp) init_quick_terminal(apprt_window &ApprtWindow) ! {
	// TODO(gtk): layer_shell.initForWindow(apprt_window.as_window()).
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
	activation_token XdgActivationTokenV1 = unsafe { nil }
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
		// TODO(gtk): connect gdk.Surface enter_monitor -> entered_monitor to
		// resize the quick terminal to the monitor. Requires GObject signal
		// wiring that is out of scope.
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
	}

	if urgent {
		token := xdg_activation_get_token(activation)!
		xdg_activation_token_set_surface(token, self.surface)
		activation_token_set_listener(token, self)
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
	// TODO(gtk): This mirrors wayland.zig's syncQuickTerminal, which drives
	// gtk4-layer-shell (setLayer/setNamespace/setKeyboardMode/setAnchor/
	// setMargin) and the org_kde_kwin_slide protocol from
	// gtk-quick-terminal-* / quick-terminal-* config. gtk4-layer-shell is an
	// external library and several of those config keys are not yet present in
	// witty's config port, so the body is deferred.
}

// --- Listeners -------------------------------------------------------------
// TODO(gtk): These correspond to wayland.zig's registryListener /
// decoManagerListener / onActivationTokenEvent. They require the generated
// wayland proxy dispatch machinery, which is out of scope. Kept as named stubs
// so the init/urgency call sites stay faithful.

// registry_set_listener installs the registry global/global_remove listener
// that binds the KDE-KWin + xdg_activation globals into the context.
fn registry_set_listener(registry WlRegistry, context &WaylandContext) {
	_ = registry
	_ = context
}

// deco_manager_set_listener installs the decoration-manager listener that
// records the compositor's default decoration mode.
fn deco_manager_set_listener(manager KdeKwinServerDecorationManager, context &WaylandContext) {
	_ = manager
	_ = context
}

// activation_token_set_listener installs the activation-token `done` listener
// that activates the surface once the token is ready.
fn activation_token_set_listener(token XdgActivationTokenV1, window &WaylandWindow) {
	_ = token
	_ = window
}

// --- Thin protocol-proxy wrappers ------------------------------------------
// TODO(gtk): Each of these wraps a single generated wayland proxy request
// (e.g. `org_kde_kwin_blur_manager_create`). Bodies are deferred until the
// wayland protocol codegen is ported; signatures are faithful so the decision
// logic above type-checks.

fn kde_decoration_manager_create(mgr KdeKwinServerDecorationManager, surface WlSurface) !KdeKwinServerDecoration {
	_ = mgr
	_ = surface
	return error('decoration manager not available')
}

fn kde_decoration_request_mode(deco KdeKwinServerDecoration, mode u32) {
	_ = deco
	_ = mode
}

fn kde_decoration_release(deco KdeKwinServerDecoration) {
	_ = deco
}

fn kde_blur_manager_create(mgr KdeKwinBlurManager, surface WlSurface) !KdeKwinBlur {
	_ = mgr
	_ = surface
	return error('blur manager not available')
}

fn kde_blur_manager_unset(mgr KdeKwinBlurManager, surface WlSurface) {
	_ = mgr
	_ = surface
}

fn kde_blur_commit(blur KdeKwinBlur) {
	_ = blur
}

fn kde_blur_release(blur KdeKwinBlur) {
	_ = blur
}

fn kde_slide_release(slide KdeKwinSlide) {
	_ = slide
}

fn xdg_activation_get_token(activation XdgActivationV1) !XdgActivationTokenV1 {
	_ = activation
	return error('xdg activation not available')
}

fn xdg_activation_token_set_surface(token XdgActivationTokenV1, surface WlSurface) {
	_ = token
	_ = surface
}

fn xdg_activation_token_commit(token XdgActivationTokenV1) {
	_ = token
}

fn xdg_activation_token_destroy(token XdgActivationTokenV1) {
	_ = token
}

// --- gtk4-layer-shell wrappers ---------------------------------------------
// TODO(gtk): gtk4-layer-shell is an external library, out of scope here.

fn layer_shell_is_supported() bool {
	return false
}

fn layer_shell_init_for_window(window GtkWindow) {
	_ = window
}
