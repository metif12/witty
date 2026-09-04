module gtk

import apprt
import core
import configpkg
import input
import global_state

// application_linux.v - The primary GTK application (AdwApplication subclass).
//
// Translated from ghostty/src/apprt/gtk/class/application.zig.
//
// In ghostty this is a GObject class (a subclass of adw.Application) created
// with `gobject.ext.defineClass`, with signal vfunc overrides and GObject
// properties. V models the private state in a stable heap wrapper, so:
//
//   * The class is modeled as a plain V struct `Application` that wraps the
//     underlying GObject pointer (`obj`) plus the private state fields that
//     ghostty keeps in its `Private` struct. Methods become ordinary
//     `pub fn (self Application)` / `pub fn Application.new(...)`.
//   * A real AdwApplication is created and its startup/activate signals invoke
//     the translated vfunc bodies. The custom `config` GObject property and
//     dispose/finalize overrides remain represented by wrapper methods.
//   * The core `App` (libghostty `CoreApp`) is the root `main.App`, which the
//     gtk module cannot import, so calls into it go through the `CoreApp`
//     placeholder (declared in app_linux.v). Method SIGNATURES are kept
//     faithful; the pure logic (config env setup, single-instance/app-id
//     resolution, action map, quit timer, quit flow) is translated directly.
//
// The apprt `App` adapter (app_linux.v) wraps this `Application` and forwards
// init/run/terminate/wakeup/perform_action to it.

// --- New C bindings --------------------------------------------------------
//
// Only functions not already declared elsewhere in the module are added here
// (see the `fn C.` grep note in the module docs). GApplication / GtkApplication
// / AdwApplication / GMainContext / GLib source + timeout functions.

// GApplication lifecycle
fn C.g_application_register(app GApplication, cancellable voidptr, error &GError) bool

fn C.g_application_activate(app GApplication)

fn C.g_application_get_is_remote(app GApplication) bool

fn C.g_application_get_flags(app GApplication) int

fn C.g_application_set_default(app GApplication)

fn C.g_application_get_default() GApplication

fn C.g_application_get_dbus_connection(app GApplication) GDBusConnection

fn C.g_application_send_notification(app GApplication, id &char, notification voidptr)

fn C.g_application_set_resource_base_path(app GApplication, resource_path &char)

// GtkApplication
fn C.gtk_application_get_windows(app GtkApplication) GList

fn C.gtk_application_set_accels_for_action(app GtkApplication, detailed_action_name &char, accels &&char)

// AdwApplication / AdwStyleManager
fn C.adw_application_get_style_manager(app AdwApplication) voidptr

fn C.adw_application_new(application_id &char, flags GApplicationFlags) AdwApplication

fn C.adw_style_manager_set_color_scheme(style_manager voidptr, color_scheme int)

fn C.adw_style_manager_get_dark(style_manager voidptr) bool

fn C.adw_init()

// GLib main loop + sources
fn C.g_main_context_default() voidptr

fn C.g_main_context_acquire(context voidptr) bool

fn C.g_main_context_release(context voidptr)

fn C.g_main_context_iteration(context voidptr, may_block bool) bool

fn C.g_main_context_wakeup(context voidptr)

fn C.g_timeout_add(interval u32, function voidptr, data voidptr) u32

fn C.g_source_remove(tag u32) bool

// GTK window helpers.
// NOTE: gtk_window_present / gtk_window_destroy / gtk_window_is_active are
// declared in window_linux.v — reused here, NOT redeclared. `is_active` there
// returns `int` (0/non-zero), which we honor below.
fn C.gtk_window_list_toplevels() GList

fn C.gtk_window_set_interactive_debugging(enable bool)

// process env
fn C.setenv(name &char, value &char, overwrite int) int

// --- AdwColorScheme -------------------------------------------------------
//
// Mirrors `adw.ColorScheme`. Values match the AdwColorScheme C enum.
pub enum AdwColorScheme {
	default_     = 0
	force_light  = 1
	prefer_light = 2
	prefer_dark  = 3
	force_dark   = 4
}

// --- GApplicationFlags ----------------------------------------------------
//
// Mirrors the `gio.ApplicationFlags` bits used here. Only `non_unique` matters
// for single-instance resolution.
pub const g_application_default_flags = 0
pub const g_application_non_unique = 0x20

// --- Quit timer state -----------------------------------------------------
//
// Mirrors the `quit_timer: union(enum) { off, active: c_uint, expired }` in the
// Zig Private struct. We model the tagged union as a tag plus the active source
// id.
pub enum QuitTimerState {
	off
	active
	expired
}

// --- Application ----------------------------------------------------------
//
// The canonical GTK application object. In ghostty this is `Application`, a
// GObject subclass of `adw.Application`; here it wraps that GObject instance
// (`obj`) and mirrors ghostty's `Private` fields inline.
//
// `@[heap]` so that the apprt `App` adapter can hold a stable `&Application`.
@[heap]
pub struct Application {
mut:
	// The underlying GtkApplication/AdwApplication instance pointer.
	obj GApplication = unsafe { nil }

	// The apprt App. Mirrors `Private.rt_app`.
	rt_app &App = unsafe { nil }

	// The libghostty App instance. Mirrors `Private.core_app`.
	core_app &core.App = unsafe { nil }

	// The configuration for the application. Mirrors `Private.config`. Since
	// the GObject `Config` wrapper is out of scope, we hold the core config
	// value directly.
	config configpkg.Config

	// State and logic for the underlying windowing protocol. Mirrors
	// `Private.winproto`.
	winproto WinProtoApp

	// The base path of the transient cgroup, if cgroups are enabled and
	// initialization succeeded. Mirrors `Private.transient_cgroup_base`.
	transient_cgroup_base ?string

	// Set true once we request a window exactly once, to prevent quitting
	// before we've shown one window. Mirrors `Private.requested_window`.
	requested_window bool

	// Set false internally when the event loop should exit and the application
	// should quit. Only set by the main loop thread. Mirrors `Private.running`.
	running bool

	// The quit timer used to quit the app after the last window is closed.
	// Mirrors `Private.quit_timer`.
	quit_timer_state  QuitTimerState = .off
	quit_timer_source u32

	// glib source id for our SIGUSR2 signal handler. Mirrors
	// `Private.signal_source`.
	signal_source ?u32

	// If non-null, we're currently showing a config errors dialog. Mirrors
	// `Private.config_errors_dialog` (a WeakRef to the dialog).
	config_errors_dialog WeakRef = weak_ref_empty()

	// CSS provider for styles derived from configuration. Mirrors
	// `Private.css_provider`. Out of scope: the actual gtk.CssProvider.
	css_provider voidptr = unsafe { nil }

	// Providers for user-defined custom stylesheets. Mirrors
	// `Private.custom_css_providers`.
	custom_css_providers []voidptr
}

// default gets this application as the default GApplication, cast to our
// `Application`. Mirrors `Application.default`.
//
// TODO(gtk): GObject class registration — ghostty casts the default
// GApplication to a `GhosttyApplication`. Here we retrieve the default
// GApplication pointer; the surrounding `Application` wrapper is reconstructed
// by `application_default()` (surface_linux.v) which owns the singleton stub.
pub fn Application.default_app() GApplication {
	return C.g_application_get_default()
}

// new creates a new Application. Mirrors `Application.new`.
//
// This does far more than a normal constructor because it is the main program
// entrypoint: it loads config, sets GTK env vars, resolves the app id and
// single-instance flags, initializes libadwaita and the windowing protocol,
// and instantiates the AdwApplication. CSS provider/property integration is
// handled separately by the translated wrapper.
pub fn Application.new(rt_app &App, core_app &core.App) !&Application {
	// Capture GLib/GObject/GTK log messages via a writer func.
	// TODO(gtk): glib.logSetWriterFunc — funnel GLib logs into witty logging.

	// Log our GTK/libadwaita versions.
	// gtk_version.logVersion(); adw_version.logVersion();

	// Set the gettext global domain so unqualified translations resolve.
	// TODO(gtk): internal_os.i18n.initGlobalDomain (i18n out of scope).

	// Load defaults, user files, command-line flags, recursive files, and theme
	// replay before GTK reads any startup settings.
	mut config := configpkg.Config.load()

	// Setup our GTK init env vars. This must happen BEFORE GTK init.
	set_gtk_env(&config)

	// Initialize libadwaita.
	C.adw_init()

	// Resolve single-instance. `detect` should have been resolved during config
	// load; we treat it as single-instance if not explicitly disabled.
	single_instance := match config.gtk_single_instance {
		.false_ { false }
		.true_ { true }
		.detect { true }
		.desktop { true }
	}

	// Setup the flags for our application.
	mut app_flags := g_application_default_flags
	if !single_instance {
		app_flags |= g_application_non_unique
	}

	// Our app id determines uniqueness and maps to our desktop file. If the
	// config specifies a valid `class`, we use it; otherwise the default id.
	mut app_id := application_id
	if class := config.class {
		if C.g_application_id_is_valid(&char(class.str)) {
			app_id = class
		} else {
			// log.warn("invalid 'class' in config, ignoring")
		}
	}

	// Setup our windowing protocol logic. A GTK application requires a display;
	// Ghostty exits when GTK cannot provide one, while this fallible constructor
	// returns the error to its caller.
	display := C.gdk_display_get_default()
	if isnil(display) {
		return error('GDK display is unavailable')
	}
	winproto := WinProtoApp.init(display, app_id, &config) or {
		// log.warn("error initializing windowing protocol")
		WinProtoApp{
			protocol: .none_
		}
	}

	// Wrap our configuration in a GObject and create the CSS provider.
	// TODO(gtk): Config.new(alloc, &config) + gtk.CssProvider.new() +
	// gtk.StyleContext.addProviderForDisplay — GObject/CSS out of scope.

	// Instantiate the application object. The Zig implementation subclasses
	// AdwApplication to install vfuncs; V connects the equivalent startup and
	// activate signals to the stable heap wrapper below.
	mut self := &Application{
		rt_app: unsafe { rt_app }
		core_app: unsafe { core_app }
		config: config
		winproto: winproto
	}
	obj := C.adw_application_new(&char(app_id.str), GApplicationFlags(app_flags))
	if isnil(obj) {
		self.winproto.deinit()
		return error('failed to create AdwApplication')
	}
	self.obj = GApplication(obj)
	C.g_application_set_resource_base_path(self.obj, c'/com/mitchellh/ghostty')
	C.g_signal_connect_data(self.obj, c'startup', GCallback(voidptr(application_startup_cb)), voidptr(self), unsafe { nil }, 0)
	C.g_signal_connect_data(self.obj, c'activate', GCallback(voidptr(application_activate_cb)), voidptr(self), unsafe { nil }, 0)

	// Signals: connect "notify::config" -> propConfig, and the CSS provider
	// "parsing-error" -> signalCssParsingError.
	// TODO(gtk): signal vfunc overrides — connections are out of scope.

	// Trigger initial config changes (notify by pspec). Here we apply the
	// config-derived setup directly.
	self.prop_config()

	return self
}

// deinit force-deinitializes the application. Mirrors `Application.deinit`.
//
// Normally the GObject finalizer would do this, but applications are never
// fully unreferenced, so this ensures cleanup happens.
pub fn (mut self Application) deinit() {
	self.winproto.deinit()
	// TODO(gtk): unref config GObject, global_shortcuts, css providers, and
	// remove style providers from the display (all GObject/CSS, out of scope).
	self.custom_css_providers = []voidptr{}
}

// core returns the core app associated with this application. Not
// reference-counted; do not store. Mirrors `Application.core`.
pub fn (self &Application) core() &core.App {
	return self.core_app
}

// winproto returns the app winproto implementation. Mirrors
// `Application.winproto`.
pub fn (mut self Application) winproto() &WinProtoApp {
	return &self.winproto
}

// cgroup_base returns the cgroup base path, if any. Mirrors
// `Application.cgroupBase`.
pub fn (self &Application) cgroup_base() ?string {
	return self.transient_cgroup_base
}

// init_quick_terminal initializes the quick terminal at the app layer for the
// given window, delegating to the active windowing protocol backend. Mirrors
// the app-side of ghostty's quick-terminal setup
// (`priv.winproto.initQuickTerminal`).
pub fn (mut self Application) init_quick_terminal(mut apprt_window ApprtWindow) ! {
	self.winproto.init_quick_terminal(mut apprt_window)!
}

// unref decrements the reference count of the Application GObject. Mirrors
// the GObject `unref`.
pub fn (mut self Application) unref() {
	if !isnil(self.obj) {
		object_unref(self.obj)
	}
}

// --- Run loop -------------------------------------------------------------

// run runs the application. This replaces `gio.Application.run` so we can
// tightly integrate the event loop with libghostty. Mirrors `Application.run`.
pub fn (mut self Application) run() ! {
	// Acquire the default main context for the application.
	ctx := C.g_main_context_default()
	if !C.g_main_context_acquire(ctx) {
		return error('context acquire failed')
	}
	defer {
		// Ensure our timer source is removed.
		self.stop_quit_timer()
		// Sync any remaining settings. (gio.Settings.sync — out of scope.)
		// Clear out the event loop without blocking.
		for C.g_main_context_iteration(ctx, false) {
		}
		// Release the context so something else can use it.
		C.g_main_context_release(ctx)
	}

	// Register the application.
	if !isnil(self.obj) {
		mut err := GError(unsafe { nil })
		if !C.g_application_register(self.obj, unsafe { nil }, &err) {
			if !isnil(err) {
				C.g_error_free(err)
			}
			return error('application register failed')
		}
		if !isnil(err) {
			C.g_error_free(err)
		}
	}

	// Fire `activate` as part of the normal startup routine, but only if the
	// config allows an initial window (background launch otherwise).
	if self.config.initial_window && !isnil(self.obj) {
		C.g_application_activate(self.obj)
	}

	// If we are NOT the primary instance, we never run the loop.
	if !isnil(self.obj) && C.g_application_get_is_remote(self.obj) {
		// log.debug("application is remote, exiting after activation")
		return
	}

	// Tell systemd that we are ready. (systemd.notify.ready — out of scope.)

	// log.debug("entering runloop")
	self.running = true
	for self.running {
		C.g_main_context_iteration(ctx, true)

		// Tick the core Ghostty terminal app.
		// TODO(gtk): core_app.tick(rt_app) — needs the real CoreApp.

		// Check if we must quit based on the current state.
		must_quit := self.must_quit()
		if must_quit {
			// All must-quit scenarios do not need confirmation, and may make it
			// unsafe to even access app/surface memory, so exit immediately.
			self.quit_now()
		}
	}
}

// must_quit computes whether the run loop should exit. Mirrors the `must_quit`
// block inside `Application.run`.
fn (self &Application) must_quit() bool {
	// If configured to always stay running, don't quit.
	if !self.config.quit_after_last_window_closed {
		return false
	}

	// If the quit timer has expired, quit.
	if self.quit_timer_state == .expired {
		// log.debug("must_quit due to quit timer expired")
		return true
	}

	// If we have no windows attached to our app, also quit — but only when no
	// closed-delay is configured (with a delay we exit eventually via timer).
	if self.config.quit_after_last_window_closed_delay == none && self.requested_window
		&& !isnil(self.obj) {
		windows := C.gtk_application_get_windows(GtkApplication(self.obj))
		if isnil(windows) {
			// log.debug("must_quit due to no app windows")
			return true
		}
	}

	return false
}

// quit starts the process to stop the run loop. It does not `exit`. Mirrors
// `Application.quit`.
pub fn (mut self Application) quit() {
	// If our run loop already exited then we're done.
	if !self.running {
		return
	}

	// If the core app doesn't need to confirm quit, exit immediately.
	// TODO(gtk): core_app.needsConfirmQuit() — needs the real CoreApp. We
	// assume no confirmation is required (the common case).
	self.quit_now()
}

// quit_now destroys all our windows and triggers the run loop exit. Mirrors
// `Application.quitNow`.
fn (mut self Application) quit_now() {
	// Get all our windows and destroy them, forcing them to free. We only
	// destroy OUR windows (they own everything else) so shutdown cascades.
	list := C.gtk_window_list_toplevels()
	// TODO(gtk): iterate the toplevel list and destroy each Window GObject via
	// `gtk_window_destroy`; the GObject `Window` type check is out of scope.
	_ = list

	// Trigger our runloop exit.
	self.running = false
}

// --- Quit timer -----------------------------------------------------------

// start_quit_timer is called when there are no more open surfaces. Mirrors
// `Application.startQuitTimer`.
fn (mut self Application) start_quit_timer() {
	// Cancel any previous timer.
	self.stop_quit_timer()

	// No-op unless we quit after the last window closes.
	if !self.config.quit_after_last_window_closed {
		return
	}

	if delay := self.config.quit_after_last_window_closed_delay {
		self.quit_timer_source = C.g_timeout_add(delay.as_milliseconds(), voidptr(handle_quit_timer_expired), voidptr(self))
		self.quit_timer_state = .active
	} else {
		// If no delay is configured, treat the timer as immediately expired.
		self.quit_timer_state = .expired
	}
}

// handle_quit_timer_expired marks the one-shot GLib timeout as expired.
fn handle_quit_timer_expired(data voidptr) int {
	if isnil(data) {
		return 0
	}
	mut self := unsafe { &Application(data) }
	self.quit_timer_state = .expired
	self.quit_timer_source = 0
	return 0
}

// stop_quit_timer is called when a new surface gets opened. Mirrors
// `Application.stopQuitTimer`.
fn (mut self Application) stop_quit_timer() {
	match self.quit_timer_state {
		.off {}
		.expired {
			self.quit_timer_state = .off
		}
		.active {
			if !C.g_source_remove(self.quit_timer_source) {
				// log.warn("unable to remove quit timer source")
			}
			self.quit_timer_state = .off
		}
	}
}

// --- Action accelerators --------------------------------------------------

// sync_action_accelerators syncs all GTK menu accelerators from the keybind
// config. Mirrors `Application.syncActionAccelerators`.
fn (mut self Application) sync_action_accelerators() {
	self.sync_action_accelerator('app.quit', input.Action.new(.quit))
	self.sync_action_accelerator('app.open-config', input.Action.new(.open_config))
	self.sync_action_accelerator('app.reload-config', input.Action.new(.reload_config))
	self.sync_action_accelerator('win.toggle-inspector', input.Action.new_enum(.inspector, i32(input.InspectorMode.toggle)))
	self.sync_action_accelerator('app.show-gtk-inspector', input.Action.new(.show_gtk_inspector))
	self.sync_action_accelerator('win.toggle-command-palette', input.Action.new(.toggle_command_palette))
	self.sync_action_accelerator('win.close', input.Action.new(.close_window))
	self.sync_action_accelerator('win.new-window', input.Action.new(.new_window))
	self.sync_action_accelerator('win.new-tab', input.Action.new(.new_tab))
	close_this := input.Action.new_enum(.close_tab, i32(input.CloseTabMode.this))
	self.sync_action_accelerator('win.close-tab::this', close_this)
	self.sync_action_accelerator('tab.close::this', close_this)
	self.sync_action_accelerator('win.split-right', input.Action.new_enum(.new_split, i32(input.SplitDirection.right)))
	self.sync_action_accelerator('win.split-down', input.Action.new_enum(.new_split, i32(input.SplitDirection.down)))
	self.sync_action_accelerator('win.split-left', input.Action.new_enum(.new_split, i32(input.SplitDirection.left)))
	self.sync_action_accelerator('win.split-up', input.Action.new_enum(.new_split, i32(input.SplitDirection.up)))
	self.sync_action_accelerator('win.copy', input.Action.new_enum(.copy_to_clipboard, i32(input.CopyToClipboard.mixed)))
	self.sync_action_accelerator('win.paste', input.Action.new(.paste_from_clipboard))
	self.sync_action_accelerator('win.reset', input.Action.new(.reset))
	self.sync_action_accelerator('win.clear', input.Action.new(.clear_screen))
	self.sync_action_accelerator('win.prompt-title', input.Action.new(.prompt_surface_title))
	self.sync_action_accelerator('split-tree.new-split::left', input.Action.new_enum(.new_split, i32(input.SplitDirection.left)))
	self.sync_action_accelerator('split-tree.new-split::right', input.Action.new_enum(.new_split, i32(input.SplitDirection.right)))
	self.sync_action_accelerator('split-tree.new-split::up', input.Action.new_enum(.new_split, i32(input.SplitDirection.up)))
	self.sync_action_accelerator('split-tree.new-split::down', input.Action.new_enum(.new_split, i32(input.SplitDirection.down)))
}

// sync_action_accelerator clears the GTK accelerator for one detailed action,
// then installs the configured trigger when it can be represented by GTK.
fn (mut self Application) sync_action_accelerator(gtk_action string, action input.Action) {
	if isnil(self.obj) {
		return
	}
	mut no_accels := unsafe { []&char{len: 1, init: &char(0)} }
	C.gtk_application_set_accels_for_action(GtkApplication(self.obj), &char(gtk_action.str), no_accels.data)
	accel := self.accelerator_for_action(action) or { return }
	mut accels := []&char{cap: 2}
	accels << &char(accel.str)
	accels << &char(unsafe { nil })
	C.gtk_application_set_accels_for_action(GtkApplication(self.obj), &char(gtk_action.str), accels.data)
}

// accelerator_for_action performs the keybind reverse lookup and trigger
// conversion shared by every menu action.
fn (self &Application) accelerator_for_action(action input.Action) ?string {
	trigger := self.config.keybind.set.get_trigger(action) or { return none }
	return accel_from_trigger(trigger)
}

// --- Properties -----------------------------------------------------------

// get_config returns the configuration for this application. Mirrors
// `Application.getConfig` (which increases the GObject ref count).
pub fn (self &Application) get_config() configpkg.Config {
	return self.config
}

// set_config sets the configuration and re-applies config-derived state.
// Mirrors `Application.setConfig`.
fn (mut self Application) set_config(config configpkg.Config) {
	self.config = config
	// notify "config" pspec -> prop_config.
	self.prop_config()
	// Show our errors if we have any.
	self.show_config_errors_dialog()
}

// prop_config responds to a "config" property change. Mirrors ghostty's
// `propConfig`: sync menu accelerators and reload runtime + custom CSS.
fn (mut self Application) prop_config() {
	// Sync our accelerators for menu items.
	self.sync_action_accelerators()

	// Load runtime + custom CSS. Failures leave the old CSS in place.
	// TODO(gtk): loadRuntimeCss / loadCustomCss — CSS provider + gtk.CssProvider
	// are out of scope. The runtime CSS generation is pure string building but
	// depends on gtk.CssProvider.loadFromBytes to apply, so it is stubbed.
}

// show_config_errors_dialog shows the config errors dialog if the config has
// diagnostics. Mirrors `Application.showConfigErrorsDialog`.
fn (mut self Application) show_config_errors_dialog() {
	// TODO(gtk): ConfigErrorsDialog GObject + WeakRef management are out of
	// scope. Diagnostics live on the config; the dialog presentation is
	// stubbed.
	if self.config.diagnostics.len == 0 {
		return
	}
}

// --- Libghostty callbacks -------------------------------------------------

// wakeup wakes up the GTK event loop. Mirrors `Application.wakeup`.
pub fn (self &Application) wakeup() {
	C.g_main_context_wakeup(unsafe { nil })
}

// --- Virtual methods (GObject vfunc overrides) ----------------------------
//
// Ghostty installs these through subclass vfuncs. The V wrapper connects the
// corresponding startup/activate GApplication signals and owns disposal.

// startup performs application startup: set as default, setup the event loop
// backend, style manager, signal handlers, action map, global shortcuts, and
// cgroup. Mirrors the `startup` vfunc.
fn (mut self Application) startup() {
	// log.debug("startup")

	// Set ourselves as the default application.
	if !isnil(self.obj) {
		C.g_application_set_default(self.obj)
	}

	// Setup our event loop backend (libxev) preference.
	self.startup_xev()

	// Setup our style manager (light/dark mode).
	self.startup_style_manager()

	// Setup some signal handlers.
	self.startup_signals()

	// Setup our action map.
	self.startup_action_map()

	// Setup our global shortcuts.
	self.startup_global_shortcuts()

	// Setup our cgroup for the application.
	self.startup_cgroup() or {
		// log.warn("cgroup initialization failed")
	}

	// Show config diagnostics if any.
	self.show_config_errors_dialog()
}

// startup_xev configures libxev to use a specific backend. Mirrors
// `Application.startupXev`.
fn (mut self Application) startup_xev() {
	// TODO(gtk): xev backend preference (async-backend config + xev.prefer)
	// needs the libxev binding; out of scope.
}

// startup_style_manager sets up the initial light/dark mode from config and
// registers a listener for changes. Mirrors `Application.startupStyleManager`.
fn (mut self Application) startup_style_manager() {
	if isnil(self.obj) {
		return
	}
	style := C.adw_application_get_style_manager(AdwApplication(self.obj))

	// Compute the initial color scheme from the window theme config.
	scheme := match self.config.window_theme {
		.auto, .ghostty {
			// Choose light/dark from the perceived luminance of the background.
			if perceived_luminance(self.config.background) > 0.5 {
				AdwColorScheme.prefer_light
			} else {
				AdwColorScheme.prefer_dark
			}
		}
		.system {
			AdwColorScheme.prefer_light
		}
		.dark {
			AdwColorScheme.force_dark
		}
		.light {
			AdwColorScheme.force_light
		}
	}
	C.adw_style_manager_set_color_scheme(style, int(scheme))

	// TODO(gtk): connect "notify::dark" -> handleStyleManagerDark (signal
	// override, out of scope). Do an initial sync.
	self.handle_style_manager_dark(style)
}

// startup_signals sets up unix signal handlers (SIGUSR2 -> reload config).
// Mirrors `Application.startupSignals`.
fn (mut self Application) startup_signals() {
	// TODO(gtk): glib.unixSignalAdd(SIGUSR2, handleSigusr2, self) — the glib
	// unix signal source is out of scope; record none.
	self.signal_source = none
}

// startup_action_map registers our GActions (new-window, open-config, quit,
// reload-config, present-surface, ...). Mirrors `Application.startupActionMap`.
fn (mut self Application) startup_action_map() {
	// The action descriptors mirror ghostty's action table. Callbacks are C
	// trampolines tied to the GObject, which is out of scope, so we build the
	// descriptor list but do not register it against a live GActionMap.
	//
	// TODO(gtk): ext.actions.add(Self, self, &actions) — needs the GObject as a
	// GActionMap and C callback trampolines.
	_ = [
		Action.new('new-window', unsafe { nil }, unsafe { nil }),
		Action.new('open-config', unsafe { nil }, unsafe { nil }),
		Action.new('quit', unsafe { nil }, unsafe { nil }),
		Action.new('reload-config', unsafe { nil }, unsafe { nil }),
	]
}

// startup_global_shortcuts sets up desktop-portal global shortcuts. Mirrors
// `Application.startupGlobalShortcuts`.
fn (mut self Application) startup_global_shortcuts() {
	// TODO(gtk): GlobalShortcuts GObject (global_shortcuts.zig) + dbus binding
	// + "config" property binding + trigger signal — all out of scope.
}

// startup_cgroup sets up the systemd cgroup for the application, if enabled.
// Mirrors `Application.startupCgroup`.
fn (mut self Application) startup_cgroup() ! {
	flags := if isnil(self.obj) {
		g_application_default_flags
	} else {
		C.g_application_get_flags(self.obj)
	}
	if !cgroup_isolation_enabled(self.config.linux_cgroup, flags) {
		return
	}

	if isnil(self.obj) {
		if self.config.linux_cgroup_hard_fail {
			return error('D-Bus connection required for cgroup isolation')
		}
		return
	}
	dbus := C.g_application_get_dbus_connection(self.obj)
	if isnil(dbus) {
		if self.config.linux_cgroup_hard_fail {
			return error('D-Bus connection required for cgroup isolation')
		}
		return
	}

	path := cgroup_init(dbus, Options{
		memory_high: self.config.linux_cgroup_memory_limit
		pids_max: self.config.linux_cgroup_processes_limit
	}) or {
		if self.config.linux_cgroup_hard_fail {
			return error('cgroup initialization failed: ${err}')
		}
		return
	}
	self.transient_cgroup_base = path
}

// cgroup_isolation_enabled applies Ghostty's mode gate. A GApplication with
// NON_UNIQUE set is not a single-instance process.
fn cgroup_isolation_enabled(mode configpkg.LinuxCgroup, app_flags int) bool {
	return match mode {
		.never { false }
		.always { true }
		.single_instance { app_flags & g_application_non_unique == 0 }
	}
}

// activate handles the GApplication "activate" signal: queue a new window.
// Mirrors the `activate` vfunc.
fn (mut self Application) activate() {
	if isnil(self.core_app) {
		return
	}
	mut core_app := unsafe { self.core_app }
	core_app.request_new_window(none)
}

// Signal trampolines install the two Application vfunc bodies on the concrete
// AdwApplication instance created by Application.new.
fn application_startup_cb(obj GApplication, user_data voidptr) {
	_ = obj
	if isnil(user_data) {
		return
	}
	mut self := unsafe { &Application(user_data) }
	self.startup()
}

fn application_activate_cb(obj GApplication, user_data voidptr) {
	_ = obj
	if isnil(user_data) {
		return
	}
	mut self := unsafe { &Application(user_data) }
	self.activate()
}

// dispose releases the config errors dialog and signal source. Mirrors the
// `dispose` vfunc.
fn (mut self Application) dispose() {
	if diag := self.config_errors_dialog.get_dialog() {
		_ = diag
		// diag.close(); diag.unref()
	}
	self.config_errors_dialog.set(unsafe { nil })

	if v := self.signal_source {
		if !C.g_source_remove(v) {
			// log.warn("unable to remove signal source")
		}
		self.signal_source = none
	}
}

// finalize force-deinitializes and chains to the parent finalizer. Mirrors the
// `finalize` vfunc.
fn (mut self Application) finalize() {
	self.deinit()
}

// --- Signal handlers ------------------------------------------------------

// handle_style_manager_dark propagates a light/dark color scheme change to the
// core app and all surfaces. Mirrors `Application.handleStyleManagerDark`.
fn (mut self Application) handle_style_manager_dark(style voidptr) {
	scheme := if !C.adw_style_manager_get_dark(style) {
		apprt.ColorScheme.light
	} else {
		apprt.ColorScheme.dark
	}
	// log.debug("style manager changed scheme")
	_ = scheme

	// TODO(gtk): core_app.colorSchemeEvent(rt, scheme) + per-surface
	// colorSchemeCallback + (GTK 4.20) css_provider "prefers-color-scheme"
	// property — need the real CoreApp/surfaces and CSS provider.
}

// --- apprt API ------------------------------------------------------------

// perform_action performs an apprt action. Mirrors `Application.performAction`.
//
// The large per-action switch in ghostty dispatches into the `Action` struct,
// which operates on the GObject `Surface`/`Window` classes (out of scope). The
// app-level actions that live entirely on the application (quit, quit_timer)
// are handled here; the rest are acknowledged as unhandled for now.
pub fn (mut self Application) perform_action(target apprt.Target, action apprt.ActionKey) !bool {
	match action {
		.quit {
			self.quit()
			return true
		}
		.quit_timer {
			// start/stop is carried in the action value; without the value we
			// default to starting the timer (ghostty branches on .start/.stop).
			self.start_quit_timer()
			return true
		}
		.show_gtk_inspector {
			C.gtk_window_set_interactive_debugging(true)
			return true
		}
		else {
			// TODO(gtk): the remaining actions dispatch into GObject
			// Surface/Window logic (Action.*), which is out of scope.
			_ = target
			return false
		}
	}
}

// --- Free helpers ---------------------------------------------------------

// perceived_luminance returns the perceived luminance (0..1) of a color using
// the same weights ghostty uses (terminal RGB perceivedLuminance). Mirrors the
// `config.background.toTerminalRGB().perceivedLuminance()` call.
fn perceived_luminance(c configpkg.ColorRGB) f64 {
	r := f64(c.r) / 255.0
	g := f64(c.g) / 255.0
	b := f64(c.b) / 255.0
	return 0.299 * r + 0.587 * g + 0.114 * b
}

// set_gtk_env sets various GTK-related environment variables (GDK_DEBUG /
// GDK_DISABLE) based on the runtime GTK version. Mirrors `setGtkEnv`.
//
// This must be called BEFORE GTK initialization.
fn set_gtk_env(config &configpkg.Config) {
	// GDK_DEBUG flags.
	mut gdk_debug := []string{}
	// GDK_DISABLE flags.
	mut gdk_disable := []string{}

	// Current gtk color management isn't good enough; disable by default on
	// versions before 4.18.
	mut disable_color_mgmt := true

	if gtk_runtime_at_least(4, 18, 0) {
		disable_color_mgmt = false
	}

	if gtk_runtime_at_least(4, 16, 0) {
		// From gtk 4.16 GDK_DEBUG split into GDK_DEBUG and GDK_DISABLE.
		gdk_disable << 'gles-api'
		gdk_disable << 'vulkan'
	} else if gtk_runtime_at_least(4, 14, 0) {
		// Needed to run on Wayland after GTK 4.14.
		gdk_debug << 'gl-disable-gles'
		gdk_debug << 'vulkan-disable'
		if gtk_runtime_until(4, 17, 5) {
			// Removed at GTK v4.17.5.
			gdk_debug << 'gl-no-fractional'
		}
	} else {
		// Versions prior to 4.14 are largely untested for ghostty.
		gdk_debug << 'vulkan-disable'
	}

	if disable_color_mgmt {
		gdk_disable << 'color-mgmt'
	}

	// gtk-opengl-debug dumps directly to stderr; both switches must be true.
	if config.gtk_opengl_debug && global_state.get_state().logging.stderr {
		gdk_debug << 'opengl'
	}

	if gdk_debug.len > 0 {
		val := gdk_debug.join(',')
		C.setenv(c'GDK_DEBUG', &char(val.str), 1)
	}
	if gdk_disable.len > 0 {
		val := gdk_disable.join(',')
		C.setenv(c'GDK_DISABLE', &char(val.str), 1)
	}
}

// find_active_window is a GCompareFunc that matches the currently-active
// toplevel window (returns 0 for a match). Mirrors `findActiveWindow`.
fn find_active_window(data voidptr, _ voidptr) int {
	if isnil(data) {
		return -1
	}
	// Confusingly, is_active returns non-zero when active but we return 0 for
	// equality, matching glib's findCustom contract.
	if C.gtk_window_is_active(GtkWindow(data)) != 0 {
		return 0
	}
	return -1
}

// get_dialog is a WeakRef accessor for the config errors dialog. Provided here
// so `dispose` can retrieve the (optional) dialog GObject.
fn (mut self WeakRef) get_dialog() ?GObject {
	obj := self.get()
	if isnil(obj) {
		return none
	}
	return obj
}
