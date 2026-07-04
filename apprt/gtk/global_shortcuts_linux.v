module gtk

// global_shortcuts_linux.v - The GObject GlobalShortcuts class for the GTK
// apprt.
//
// Translated from ghostty/src/apprt/gtk/class/global_shortcuts.zig.
//
// The Zig original is a GObject class (`GhosttyGlobalShortcuts`, a plain
// `gobject.Object`) that registers system-wide keyboard shortcuts through the
// XDG Desktop Portal (`org.freedesktop.portal.GlobalShortcuts`), speaking to
// `org.freedesktop.portal.Desktop` over D-Bus. When a registered shortcut is
// activated by the desktop, it emits a `trigger` signal carrying the bound
// `input.Action`.
//
// FOLLOWING THE ESTABLISHED PATTERN (see application_linux.v / window_linux.v):
//   * The class is modeled as a plain V struct `GlobalShortcuts` wrapping the
//     underlying `gobject.Object` pointer (`obj`) plus the fields ghostty keeps
//     in its `Private` struct (config, dbus_connection, the id->action map, the
//     portal session handle, and the two D-Bus signal subscription ids).
//   * GObject type registration (`defineClass`), the `config` /
//     `dbus-connection` PROPERTIES, the `trigger` SIGNAL emission, the
//     `dispose` vfunc, and the async D-Bus reply callbacks / variadic
//     `g_variant_new_parsed` payload construction are STUBBED with `// TODO(gtk)`
//     and minimal type-checking bodies.
//   * The TRACTABLE structural logic IS translated: the portal session
//     create -> bind -> list flow (`Method`, `request`, `refresh`), the
//     shortcut-id <-> trigger mapping (via `xdg_shortcut_from_trigger` in
//     key_linux.v), the request-path construction (unique-name based, with the
//     leading `:` stripped and `.` -> `_`), the response dispatch, the keybind
//     activation handling, and the D-Bus signal subscription structure.
//
// Cross-references / reuse:
//   * `GDBusConnection` / `GVariant` / `GVariantType` / `GError` / `GCallback`
//     and the `g_variant_*` / `g_dbus_connection_call*` bindings come from
//     ipc_dbus_linux.v / ext_actions_linux.v / c_gtk_linux.v (NOT redeclared).
//   * `Config` is the GObject config wrapper (config_class_linux.v).
//   * `Application` is the GObject application class (application_linux.v).
//   * `xdg_shortcut_from_trigger` (key_linux.v) turns a trigger into the
//     XDG-compliant shortcut string used as the unique id.
//
// Only the *new* D-Bus C functions this file needs are declared below.

import input
import rand

// --- New D-Bus C bindings -------------------------------------------------
//
// Grep-verified: none of these are declared elsewhere in the module. The
// synchronous `g_dbus_connection_call_sync` and the GVariant/GVariantType
// helpers live in ipc_dbus_linux.v and are reused.

// Subscribe to a D-Bus signal. Returns a non-zero subscription id (0 is used
// as the "no subscription" sentinel). `flags` is a GDBusSignalFlags bitmask.
fn C.g_dbus_connection_signal_subscribe(connection GDBusConnection, sender &char, interface_name &char, member &char, object_path &char, arg0 &char, flags int, callback GCallback, user_data voidptr, user_data_free_func voidptr) u32

// Remove a previously-installed signal subscription.
fn C.g_dbus_connection_signal_unsubscribe(connection GDBusConnection, subscription_id u32)

// Asynchronous method call (fire-and-forget / with async callback). Mirrors
// `dbus.call(...)` in the Zig original.
fn C.g_dbus_connection_call(connection GDBusConnection, bus_name &char, object_path &char, interface_name &char, method_name &char, parameters GVariant, reply_type GVariantType, flags int, timeout_msec int, cancellable voidptr, callback GCallback, user_data voidptr)

// The bus-unique name of the connection (e.g. ":1.192"), or nil.
fn C.g_dbus_connection_get_unique_name(connection GDBusConnection) &char

// --- Portal constants -----------------------------------------------------
//
// Well-known bus name / object paths / interface names for the XDG Desktop
// Portal GlobalShortcuts API.
const portal_bus_name = 'org.freedesktop.portal.Desktop'
const portal_object_path = '/org/freedesktop/portal/desktop'
const portal_iface_global_shortcuts = 'org.freedesktop.portal.GlobalShortcuts'
const portal_iface_request = 'org.freedesktop.portal.Request'
const portal_iface_session = 'org.freedesktop.portal.Session'

// GDBusSignalFlags bits we use. `match_arg0_path` matches arg0 as an object
// path prefix (used to scope the "Activated" signal to our session handle).
const g_dbus_signal_flags_none = 0
const g_dbus_signal_flags_match_arg0_path = 1 << 1

// GDBusCallFlags: we always pass "none".
const g_dbus_call_flags_none = 0

// --- Method ---------------------------------------------------------------

// Method enumerates the two portal methods we invoke, in order. Mirrors the
// Zig `Method` enum.
pub enum Method {
	create_session
	bind_shortcuts
}

// method_name returns the D-Bus method name for a Method. Mirrors `Method.name`.
fn (m Method) method_name() string {
	return match m {
		.create_session { 'CreateSession' }
		.bind_shortcuts { 'BindShortcuts' }
	}
}

// --- ShortcutMapEntry -----------------------------------------------------
//
// A single unique-id -> action mapping. Ghostty uses a
// `StringArrayHashMapUnmanaged(Binding.Action)` keyed by the serialized
// trigger (the XDG shortcut string). witty models the map as a slice (matching
// the codebase's preference; see input.Set.bindings) so lookups and iteration
// stay explicit.
struct ShortcutMapEntry {
	// The unique shortcut id (the XDG-compliant trigger string, e.g. "CTRL+a").
	id string
	// The action bound to that shortcut.
	action input.Action
}

// --- GlobalShortcuts ------------------------------------------------------
//
// The GObject GlobalShortcuts class. In ghostty this is `GlobalShortcuts`, a
// `gobject.Object` subclass; here it wraps that GObject instance (`obj`) and
// mirrors ghostty's `Private` fields inline.
//
// `@[heap]` so the application can hold a stable `&GlobalShortcuts`.
@[heap]
pub struct GlobalShortcuts {
mut:
	// The underlying GObject instance pointer.
	//
	// TODO(gtk): GObject class registration — in ghostty this is created via
	// `gobject.ext.newInstance`; here it is a stubbed handle.
	obj GObject = unsafe { nil }

	// The configuration this is using. Mirrors `Private.config`.
	config &Config = unsafe { nil }

	// The D-Bus connection. Mirrors `Private.dbus_connection`.
	dbus_connection GDBusConnection = unsafe { nil }

	// A mapping from a unique id to an action. Currently the unique id is simply
	// the serialized representation of the trigger that was used for the action,
	// as triggers are unique in the keymap. Mirrors `Private.map`.
	//
	// NOTE: ghostty keeps this in a per-refresh arena; V is GC-managed so we
	// just reset the slice on each refresh.
	map []ShortcutMapEntry

	// The handle of the current global shortcuts portal session, as a D-Bus
	// object path. Empty means "no session". Mirrors `Private.handle`.
	handle string

	// The D-Bus signal subscription for the response signal on requests. The id
	// is guaranteed non-zero, so 0 indicates "none". Mirrors
	// `Private.response_subscription`.
	response_subscription u32

	// The D-Bus signal subscription for the keybind activate signal. Mirrors
	// `Private.activate_subscription`.
	activate_subscription u32
}

// global_shortcuts_new creates a new GlobalShortcuts. Mirrors the implicit
// `gobject.ext.newInstance` constructor + `init`.
//
// TODO(gtk): GObject class registration — ghostty's `init` connects
// "notify::config" -> propConfig. Here we allocate the plain wrapper and rely
// on `set_config` / `set_dbus_connection` to drive refreshes.
pub fn GlobalShortcuts.new() &GlobalShortcuts {
	return &GlobalShortcuts{
		obj: unsafe { nil }
	}
}

// --- Lifecycle ------------------------------------------------------------

// close tears down all portal state: the two signal subscriptions and the
// portal session. Mirrors `GlobalShortcuts.close`.
fn (mut self GlobalShortcuts) close() {
	dbus := self.dbus_connection
	if isnil(dbus) {
		return
	}

	if self.response_subscription != 0 {
		C.g_dbus_connection_signal_unsubscribe(dbus, self.response_subscription)
		self.response_subscription = 0
	}

	if self.activate_subscription != 0 {
		C.g_dbus_connection_signal_unsubscribe(dbus, self.activate_subscription)
		self.activate_subscription = 0
	}

	if self.handle.len > 0 {
		// Close the existing session.
		C.g_dbus_connection_call(dbus, &char(portal_bus_name.str), &char(self.handle.str),
			&char(portal_iface_session.str), c'Close', GVariant(unsafe { nil }), GVariantType(unsafe { nil }),
			g_dbus_call_flags_none, -1, unsafe { nil }, GCallback(unsafe { nil }), unsafe { nil })
		self.handle = ''
	}

	// Our map lived in the (now-released) refresh arena in ghostty; reset it.
	self.map = []ShortcutMapEntry{}
}

// refresh rebuilds the id->action map from the config keybinds and, if there
// are any global shortcuts, (re)creates the portal session. Mirrors
// `GlobalShortcuts.refresh`.
fn (mut self GlobalShortcuts) refresh() {
	// Always close our previous state first.
	self.close()

	// We need configuration to proceed.
	if isnil(self.config) {
		return
	}
	config := self.config.get()

	// Our map starts out empty again.
	mut new_map := []ShortcutMapEntry{}

	// Update the map from the keybind set, keeping only global, single-action
	// leaves whose trigger can be represented as an XDG shortcut string.
	//
	// TODO(gtk): the placeholder `configpkg.Config` does not yet carry a keybind
	// `Set` (`config.keybind.set.bindings`), so we cannot iterate the real
	// bindings. The faithful structure is preserved below; once the config
	// exposes a keybind Set, restore the loop over `config.keybind.set.bindings`
	// and drop this early guard.
	_ = config
	self.refresh_map_from_bindings(mut new_map)

	self.map = new_map

	// Create our session if we have any global shortcuts.
	if self.map.len > 0 {
		self.request(.create_session)
	}
}

// refresh_map_from_bindings is the translated body of ghostty's binding loop in
// `refresh`. It iterates the config keybind set, keeps global single-action
// leaves, and maps each such binding's XDG shortcut string to its action.
//
// TODO(gtk): this receives an empty binding set today (the placeholder config
// has no keybind `Set`). The real loop — kept here in structure — is:
//
//   for entry in config.keybind.set.bindings {
//       leaf := match entry.value.typ {
//           .leader { continue }
//           .leaf, .leaf_chained { entry.value.generic() }
//       }
//       if !leaf.flags.global { continue }
//       actions := leaf.actions_slice()
//       if actions.len != 1 { continue }
//       shortcut := xdg_shortcut_from_trigger(entry.trigger) or { continue }
//       new_map << ShortcutMapEntry{ id: shortcut, action: actions[0] }
//   }
fn (mut self GlobalShortcuts) refresh_map_from_bindings(mut new_map []ShortcutMapEntry) {
	// Intentionally empty: no keybind Set available on the placeholder config.
	// The per-binding translation (global filter + single-action restriction +
	// `xdg_shortcut_from_trigger`) is available via `map_binding` below and is
	// wired here once the config exposes a keybind Set.
	_ = new_map
}

// map_binding is the per-binding translation extracted from ghostty's `refresh`
// loop: it returns the id->action entry for a single global binding, or `none`
// if the binding should be skipped (not global, not exactly one action, or the
// trigger cannot be represented as an XDG shortcut). Kept as a standalone fn so
// the real logic is exercised/type-checked even while `refresh` has no Set to
// iterate.
fn map_binding(trigger input.Trigger, flags input.Flags, actions []input.Action) ?ShortcutMapEntry {
	// Only global keybinds are registered with the portal.
	if !flags.global {
		return none
	}

	// We only allow global keybinds that map to exactly a single action for now.
	// TODO: remove this restriction (matches ghostty's TODO).
	if actions.len != 1 {
		return none
	}

	// Translate the trigger into the XDG-compliant shortcut string used as the
	// unique id. `none` means the trigger cannot be represented (e.g. catch_all).
	shortcut := xdg_shortcut_from_trigger(trigger) or { return none }

	return ShortcutMapEntry{
		id:     shortcut
		action: actions[0]
	}
}

// --- Requests -------------------------------------------------------------

// request submits a request to the global shortcuts portal.
//
// NOTE(pluiedev, ghostty): XDG portals require the client to manually construct
// the expected Request object path and subscribe to its "Response" signal
// BEFORE issuing the call, because the server may emit the response before the
// original call even returns (a race the protocol never fixed). So we:
//
//   1. generate a request token,
//   2. build the method payload,
//   3. compute the deterministic request path from our bus-unique name,
//   4. subscribe to the "Response" signal at that path,
//   5. issue the actual portal call.
//
// Mirrors `GlobalShortcuts.request`.
fn (mut self GlobalShortcuts) request(method Method) {
	dbus := self.dbus_connection
	if isnil(dbus) {
		return
	}

	request_token := generate_token()

	// Build the payload for this method. A nil payload (e.g. bind_shortcuts with
	// no session handle yet) means "nothing to do".
	payload := self.make_payload(method, request_token) or { return }

	// Compute the request path we must listen on.
	request_path := self.get_request_path(request_token) or { return }

	// Subscribe to the response signal BEFORE issuing the call (see NOTE above).
	// The Zig callback `responded` handles the reply; wiring that C trampoline
	// is out of scope, so we register a nil callback placeholder.
	//
	// TODO(gtk): pass the `responded` C callback that: unsubscribes the response
	// signal, unpacks `(u@a{sv})`, and on success dispatches
	// `on_response(method, vardict)`.
	if self.response_subscription != 0 {
		// Precondition in ghostty is that this is 0; defensively clear a stale one.
		C.g_dbus_connection_signal_unsubscribe(dbus, self.response_subscription)
		self.response_subscription = 0
	}
	self.response_subscription = C.g_dbus_connection_signal_subscribe(dbus, unsafe { nil },
		&char(portal_iface_request.str), c'Response', &char(request_path.str), unsafe { nil },
		g_dbus_signal_flags_none, GCallback(unsafe { nil }), voidptr(self), unsafe { nil })

	// Issue the actual portal call. The async reply callback `gotResponseHandle`
	// only logs errors / would reconcile the request path; stubbed as nil.
	//
	// TODO(gtk): pass the `got_response_handle` C callback (calls
	// `g_dbus_connection_call_finish`, logs failures).
	C.g_dbus_connection_call(dbus, &char(portal_bus_name.str), &char(portal_object_path.str),
		&char(portal_iface_global_shortcuts.str), &char(method.method_name().str), payload,
		GVariantType(unsafe { nil }), g_dbus_call_flags_none, -1, unsafe { nil }, GCallback(unsafe { nil }),
		voidptr(self))
}

// make_payload constructs the GVariant payload expected by the portal call for
// `method`. Mirrors `Method.makePayload`. Returns `none` when there is nothing
// to send (bind_shortcuts before we have a session handle).
fn (mut self GlobalShortcuts) make_payload(method Method, request_token string) ?GVariant {
	match method {
		.create_session {
			// See the CreateSession portal docs. The real payload is:
			//   ({'handle_token': <request_token>,
			//     'session_handle_token': <session_token>},)
			// built via `glib.Variant.newParsed(...)`.
			session_token := generate_token()
			_ = session_token
			// TODO(gtk): g_variant_new_parsed is variadic and is not yet bound in
			// the module; build the "({'handle_token': <%s>, 'session_handle_token':
			// <%s>},)" variant with `request_token` and `session_token`.
			_ = request_token
			return GVariant(unsafe { nil })
		}
		.bind_shortcuts {
			// Requires an existing session handle.
			if self.handle.len == 0 {
				return none
			}

			// The real payload is:
			//   (session_handle, a(sa{sv}) binds, '', {'handle_token': <token>})
			// where each bind is:
			//   (trigger_id, {'description': <action_str>,
			//                 'preferred_trigger': <trigger_id>})
			//
			// The bind array is built here from `self.map`; the action
			// description is the action's stringified form.
			for entry in self.map {
				trigger_id := entry.id
				description := action_to_string(entry.action)
				// TODO(gtk): binds.addParsed("(%s, {'description': <%s>,
				// 'preferred_trigger': <%s>})", trigger_id, description, trigger_id)
				// via a GVariantBuilder over type "a(sa{sv})".
				_ = trigger_id
				_ = description
			}

			// TODO(gtk): g_variant_new_parsed("(%o, %*, '', {'handle_token': <%s>})",
			// self.handle, binds.end(), request_token).
			_ = request_token
			return GVariant(unsafe { nil })
		}
	}
}

// on_response dispatches a successful portal response for `method`. Mirrors
// `Method.onResponse`.
fn (mut self GlobalShortcuts) on_response(method Method, vardict GVariant) {
	match method {
		.create_session {
			dbus := self.dbus_connection
			if isnil(dbus) {
				return
			}

			// Extract the session handle from the response vardict.
			//   vardict.lookup("session_handle", "&s", &handle)
			handle := self.lookup_session_handle(vardict) or {
				// log.warn("session handle not found in response")
				return
			}
			self.handle = handle

			// Subscribe to keybind activations, scoped (by arg0-path) to our
			// session handle. Precondition: no existing activate subscription.
			if self.activate_subscription == 0 {
				// TODO(gtk): pass the `shortcut_activated` C callback (see
				// `shortcut_activated` below).
				self.activate_subscription = C.g_dbus_connection_signal_subscribe(dbus,
					unsafe { nil }, &char(portal_iface_global_shortcuts.str), c'Activated',
					&char(portal_object_path.str), &char(self.handle.str), g_dbus_signal_flags_match_arg0_path,
					GCallback(unsafe { nil }), voidptr(self), unsafe { nil })
			}

			// Now that we have a session, bind our shortcuts.
			self.request(.bind_shortcuts)
		}
		.bind_shortcuts {
			// Nothing to do on a successful bind.
		}
	}
}

// lookup_session_handle extracts the "session_handle" object-path string from a
// CreateSession response vardict. Mirrors the `vardict.lookup(...)` call.
fn (self &GlobalShortcuts) lookup_session_handle(vardict GVariant) ?string {
	_ = vardict
	// TODO(gtk): g_variant_lookup(vardict, "session_handle", "&s", &handle) and
	// dup the returned C string. Returns `none` when the key is absent.
	return none
}

// get_request_path computes the XDG portal Request object path for this
// connection + token. Mirrors `GlobalShortcuts.getRequestPath`.
//
// The portal derives the path deterministically from the client's bus-unique
// name so the client can subscribe to the response before issuing the call.
// The path is:
//
//   /org/freedesktop/portal/desktop/request/<sanitized-unique-name>/<token>
//
// where the unique name has its leading `:` stripped and every `.` replaced by
// `_` (valid D-Bus object-path components never contain `.`).
//
// Precondition: the D-Bus connection exists.
fn (self &GlobalShortcuts) get_request_path(token string) ?string {
	dbus := self.dbus_connection
	if isnil(dbus) {
		return none
	}

	// `getUniqueName` should never be nil on an ordinary message-bus connection.
	unique_name_c := C.g_dbus_connection_get_unique_name(dbus)
	if isnil(unique_name_c) {
		return none
	}
	unique_name := unsafe { cstring_to_vstring(unique_name_c) }
	if unique_name.len == 0 {
		return none
	}

	// Strip the leading ':' and replace '.' with '_' in the unique name.
	sanitized := unique_name[1..].replace('.', '_')

	return '/org/freedesktop/portal/desktop/request/${sanitized}/${token}'
}

// --- Property handlers ----------------------------------------------------

// set_config sets the configuration and re-refreshes the shortcut
// registrations. Mirrors ghostty's `config` property setter + `propConfig`
// (which calls `refresh` on a "notify::config").
pub fn (mut self GlobalShortcuts) set_config(config &Config) {
	if !isnil(self.config) {
		object_unref(self.config.obj)
	}
	self.config = unsafe { config }
	if !isnil(config) {
		object_ref(config.obj)
	}
	self.refresh()
}

// set_dbus_connection sets (or clears) the D-Bus connection. Setting a new
// connection triggers a refresh; clearing/replacing first closes prior portal
// registrations. Mirrors `GlobalShortcuts.setDbusConnection`.
pub fn (mut self GlobalShortcuts) set_dbus_connection(dbus_connection GDBusConnection) {
	// If we have a prior connection, close our prior registrations first.
	if !isnil(self.dbus_connection) {
		self.close()
		object_unref(self.dbus_connection)
		self.dbus_connection = unsafe { nil }
	}

	self.dbus_connection = unsafe { nil }
	if !isnil(dbus_connection) {
		object_ref(dbus_connection)
		self.dbus_connection = dbus_connection
		self.refresh()
	}

	// TODO(gtk): notify the "dbus-connection" property pspec.
}

// --- Signal handlers ------------------------------------------------------

// shortcut_activated is the D-Bus "Activated" signal handler. The 2nd value of
// the signal tuple is the activated shortcut id; we look up its action and emit
// our `trigger` signal. Mirrors `GlobalShortcuts.shortcutActivated`.
//
// TODO(gtk): in ghostty this is a C signal-subscription callback with the full
// (dbus, sender, path, iface, signal, params, user_data) signature. Here we
// model just the payload-processing core keyed on the extracted shortcut id.
fn (mut self GlobalShortcuts) shortcut_activated(shortcut_id string) {
	// Look up the action bound to this shortcut id.
	action := self.action_for_id(shortcut_id) or { return }

	// Emit the "trigger" signal with a pointer to the action.
	self.emit_trigger(action)
}

// action_for_id returns the action bound to a shortcut id, or `none`. Mirrors
// the `priv.map.get(shortcut_id)` lookup.
fn (self &GlobalShortcuts) action_for_id(id string) ?input.Action {
	for entry in self.map {
		if entry.id == id {
			return entry.action
		}
	}
	return none
}

// emit_trigger emits the "trigger" signal carrying the activated action.
// Mirrors `signals.trigger.impl.emit(self, null, .{&action}, null)`.
fn (self &GlobalShortcuts) emit_trigger(action input.Action) {
	_ = action
	// TODO(gtk): emit the `trigger` signal with a pointer to the action. The
	// GObject signal machinery is out of scope.
}

// --- Virtual methods ------------------------------------------------------

// dispose closes all connections and drops the config/dbus references. Mirrors
// the `dispose` vfunc. Ghostty closes here (not in finalize) because dropping
// references may take away access to the dbus connection.
pub fn (mut self GlobalShortcuts) dispose() {
	self.close()

	if !isnil(self.config) {
		object_unref(self.config.obj)
		self.config = unsafe { nil }
	}
	if !isnil(self.dbus_connection) {
		object_unref(self.dbus_connection)
		self.dbus_connection = unsafe { nil }
	}

	// TODO(gtk): chain up to gobject.Object dispose.
}

// --- Free helpers ---------------------------------------------------------

// generate_token generates a random token suitable for use in portal requests.
// Mirrors the Zig `generateToken` (which formats a random `u28` as hex behind a
// "ghostty_" prefix). The exact bit-width is not load-bearing; any unique,
// object-path-component-safe token works.
fn generate_token() string {
	return 'ghostty_${rand.u32() & 0xfffffff:07x}'
}

// action_to_string renders an action as the human-readable description used in
// the bind payload. Mirrors ghostty's `{f}` formatting of `Binding.Action`.
//
// TODO(gtk): witty's `input.Action` has no full string formatter; we use the
// action tag name (stable + unique per tag), matching the approach taken in
// command_palette_linux.v (`prop_get_action_key`).
fn action_to_string(action input.Action) string {
	return action.tag.str()
}

// --- GObject class registration (stub) ------------------------------------
//
// TODO(gtk): In ghostty `GhosttyGlobalShortcuts` is registered via
// `gobject.ext.defineClass`. Its classInit registers the `config` and
// `dbus-connection` properties, registers the `trigger` signal, and wires the
// `dispose` vfunc; its instanceInit connects "notify::config" -> propConfig. V
// has no such machinery, so all of that is stubbed; the handlers above are
// plain methods driven directly by `set_config` / `set_dbus_connection`.
