@[has_globals]
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
// The class is a real GhosttyGlobalShortcuts GObject subclass backed by a
// stable V wrapper. Its config/dbus properties, trigger signal, reference
// ownership, and dispose chain use the native GObject contract; the portal
// session create -> bind flow and shortcut mapping are translated directly.
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

// Complete an asynchronous D-Bus call.
pub type GAsyncResult = voidptr

fn C.g_dbus_connection_call_finish(connection GDBusConnection, result GAsyncResult, error &GError) GVariant

// Non-variadic GVariant construction and accessors used by the portal
// payloads and signal callbacks.
fn C.g_variant_new_object_path(path &char) GVariant

fn C.g_variant_get_child_value(value GVariant, index usize) GVariant

fn C.g_variant_get_uint32(value GVariant) u32

fn C.g_variant_get_string(value GVariant, length &usize) &char

fn C.g_variant_lookup_value(dictionary GVariant, key &char, expected_type GVariantType) GVariant

// The bus-unique name of the connection (e.g. ":1.192"), or nil.
fn C.g_dbus_connection_get_unique_name(connection GDBusConnection) &char

fn C.g_dbus_connection_get_type() GType

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
pub enum Method as u8 {
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

// A string-valued a{sv} entry. Portal option dictionaries only need string
// values in this class.
struct VariantStringEntry {
	key   string
	value string
}

// --- GObject class registration ------------------------------------------

__global g_global_shortcuts_type = GType(0)
__global g_global_shortcuts_pspec_config = &C.GParamSpec(unsafe { nil })
__global g_global_shortcuts_pspec_dbus_connection = &C.GParamSpec(unsafe { nil })

struct C.GhosttyGlobalShortcutsPrivate {
mut:
	wrapper voidptr
}

const global_shortcuts_prop_config = u32(1)
const global_shortcuts_prop_dbus_connection = u32(2)
const global_shortcuts_param_static_strings = int(32 | 64 | 128)

fn global_shortcuts_priv(obj voidptr) &C.GhosttyGlobalShortcutsPrivate {
	return &C.GhosttyGlobalShortcutsPrivate(C.g_type_instance_get_private(obj, g_global_shortcuts_type))
}

fn global_shortcuts_get_property(obj voidptr, property_id u32, value voidptr, pspec voidptr) {
	_ = pspec
	priv := global_shortcuts_priv(obj)
	if isnil(priv.wrapper) {
		return
	}
	self := unsafe { &GlobalShortcuts(priv.wrapper) }
	match property_id {
		global_shortcuts_prop_config {
			if isnil(self.config) {
				C.g_value_set_object(value, unsafe { nil })
			} else {
				C.g_value_set_object(value, self.config.obj)
			}
		}
		global_shortcuts_prop_dbus_connection {
			C.g_value_set_object(value, self.dbus_connection)
		}
		else {}
	}
}

fn global_shortcuts_set_property(obj voidptr, property_id u32, value voidptr, pspec voidptr) {
	_ = pspec
	priv := global_shortcuts_priv(obj)
	if isnil(priv.wrapper) {
		return
	}
	mut self := unsafe { &GlobalShortcuts(priv.wrapper) }
	match property_id {
		global_shortcuts_prop_config {
			config_obj := C.g_value_get_object(value)
			if isnil(config_obj) {
				self.set_config_reference(unsafe { nil })
			} else {
				config_private := config_priv(config_obj)
				self.set_config_reference(if isnil(config_private.wrapper) {
					unsafe { nil }
				} else {
					unsafe { &Config(config_private.wrapper) }
				})
			}
		}
		global_shortcuts_prop_dbus_connection {
			self.set_dbus_reference(GDBusConnection(C.g_value_get_object(value)))
		}
		else {}
	}
}

fn global_shortcuts_notify_config_cb(obj voidptr, pspec voidptr, data voidptr) {
	_ = obj
	_ = pspec
	if !isnil(data) {
		mut self := unsafe { &GlobalShortcuts(data) }
		self.refresh()
	}
}

fn global_shortcuts_dispose_object(obj voidptr) {
	priv := global_shortcuts_priv(obj)
	if !isnil(priv.wrapper) {
		mut self := unsafe { &GlobalShortcuts(priv.wrapper) }
		self.dispose_resources()
	}
	C.witty_gobject_call_parent_dispose(obj)
}

fn global_shortcuts_finalize_object(obj voidptr) {
	mut priv := global_shortcuts_priv(voidptr(obj))
	if !isnil(priv.wrapper) {
		mut self := unsafe { &GlobalShortcuts(priv.wrapper) }
		self.obj = unsafe { nil }
		priv.wrapper = unsafe { nil }
	}
	C.witty_gobject_call_parent_finalize(obj)
}

fn global_shortcuts_class_init(klass voidptr, class_data voidptr) {
	_ = class_data
	_ = config_get_type()
	C.witty_gobject_class_set_get_property(klass, voidptr(global_shortcuts_get_property))
	C.witty_gobject_class_set_set_property(klass, voidptr(global_shortcuts_set_property))
	C.witty_gobject_class_set_dispose(klass, voidptr(global_shortcuts_dispose_object))
	C.witty_gobject_class_set_finalize(klass, voidptr(global_shortcuts_finalize_object))
	readwrite := g_param_readwrite | global_shortcuts_param_static_strings
	nil_str := &char(unsafe { nil })
	g_global_shortcuts_pspec_config = C.g_param_spec_object(c'config', nil_str, nil_str, config_get_type(), readwrite)
	g_global_shortcuts_pspec_dbus_connection = C.g_param_spec_object(c'dbus-connection', nil_str, nil_str, C.g_dbus_connection_get_type(), readwrite)
	C.g_object_class_install_property(klass, global_shortcuts_prop_config, g_global_shortcuts_pspec_config)
	C.g_object_class_install_property(klass, global_shortcuts_prop_dbus_connection, g_global_shortcuts_pspec_dbus_connection)
	C.g_signal_new(c'trigger', g_global_shortcuts_type, g_signal_run_last, 0, unsafe { nil }, unsafe { nil }, unsafe { nil }, GType(4), 1, g_type_pointer)
}

fn global_shortcuts_instance_init(instance voidptr, klass voidptr) {
	_ = instance
	_ = klass
}

pub fn global_shortcuts_get_type() GType {
	if g_global_shortcuts_type == GType(0) {
		parent := C.g_object_get_type()
		mut query := C.GTypeQuery{}
		C.g_type_query(parent, &query)
		info := C.GTypeInfo{
			class_size: u16(query.class_size)
			instance_size: u16(query.instance_size)
			class_init: voidptr(global_shortcuts_class_init)
			instance_init: voidptr(global_shortcuts_instance_init)
		}
		g_global_shortcuts_type = C.g_type_register_static(parent, c'GhosttyGlobalShortcuts', &info, 0)
		_ = C.g_type_add_instance_private(g_global_shortcuts_type, sizeof(C.GhosttyGlobalShortcutsPrivate))
	}
	return g_global_shortcuts_type
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

	// The response subscription is method-specific in Ghostty because the Zig
	// callback is instantiated at comptime. V uses one C trampoline and records
	// which request it belongs to here.
	pending_method     Method
	has_pending_method bool

	// V-side equivalent of the GObject `trigger` signal connection. The real
	// signal is still emitted when this wrapper owns a registered GObject.
	trigger_handler ?fn (action input.Action, user_data voidptr)
	trigger_data    voidptr = unsafe { nil }
}

// global_shortcuts_new creates a native GhosttyGlobalShortcuts instance and
// connects the pinned notify::config refresh handler.
pub fn GlobalShortcuts.new() &GlobalShortcuts {
	obj := GObject(C.g_object_new(global_shortcuts_get_type(), &char(unsafe { nil })))
	mut self := &GlobalShortcuts{
		obj: obj
	}
	mut priv := global_shortcuts_priv(voidptr(obj))
	priv.wrapper = voidptr(self)
	C.g_signal_connect_data(obj, c'notify::config', GCallback(voidptr(global_shortcuts_notify_config_cb)), voidptr(self), unsafe { nil }, 0)
	return self
}

pub fn (mut self GlobalShortcuts) ref() &GlobalShortcuts {
	if !isnil(self.obj) {
		object_ref(self.obj)
	}
	return self
}

pub fn (mut self GlobalShortcuts) unref() {
	if !isnil(self.obj) {
		object_unref(self.obj)
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
	self.has_pending_method = false

	if self.activate_subscription != 0 {
		C.g_dbus_connection_signal_unsubscribe(dbus, self.activate_subscription)
		self.activate_subscription = 0
	}

	if self.handle.len > 0 {
		// Close the existing session.
		C.g_dbus_connection_call(dbus, &char(portal_bus_name.str), &char(self.handle.str), &char(portal_iface_session.str), c'Close', GVariant(unsafe { nil }), GVariantType(unsafe { nil }), g_dbus_call_flags_none, -1, unsafe { nil }, GCallback(unsafe { nil }), unsafe { nil })
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

	// Our map starts out empty again.
	mut new_map := []ShortcutMapEntry{}

	// Update the map from the keybind set, keeping only global, single-action
	// leaves whose trigger can be represented as an XDG shortcut string.
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
fn (mut self GlobalShortcuts) refresh_map_from_bindings(mut new_map []ShortcutMapEntry) {
	if isnil(self.config) {
		return
	}
	config := self.config.get()
	for entry in config.keybind.set.bindings {
		mapped := match entry.value.typ {
			.leader {
				continue
			}
			.leaf {
				map_binding(entry.trigger, entry.value.leaf_flags, [
					entry.value.leaf_action,
				]) or {
					continue
				}
			}
			.leaf_chained {
				map_binding(entry.trigger, entry.value.chain_flags, entry.value.chain_actions) or {
					continue
				}
			}
		}
		new_map << mapped
	}
}

// map_binding is the per-binding translation extracted from ghostty's `refresh`
// loop: it returns the id->action entry for a single global binding, or `none`
// if the binding should be skipped (not global, not exactly one action, or the
// trigger cannot be represented as an XDG shortcut). Kept as a standalone fn so
// the real logic is exercised/type-checked even while `refresh` has no Set to
// iterate.
fn map_binding(trigger input.Trigger, flags input.Flags, actions []input.Action) ?ShortcutMapEntry {
	// Only global keybinds are registered with the portal.
	if !flags.global() {
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
		id: shortcut
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
	if self.response_subscription != 0 {
		// Precondition in ghostty is that this is 0; defensively clear a stale one.
		C.g_dbus_connection_signal_unsubscribe(dbus, self.response_subscription)
		self.response_subscription = 0
	}
	self.pending_method = method
	self.has_pending_method = true
	self.response_subscription = C.g_dbus_connection_signal_subscribe(dbus, unsafe { nil }, &char(portal_iface_request.str), c'Response', &char(request_path.str), unsafe { nil }, g_dbus_signal_flags_none, GCallback(voidptr(global_shortcuts_responded_cb)), voidptr(self), unsafe { nil })

	// Issue the actual portal call. The async reply only reports transport-level
	// failure; the portal result arrives on the Response signal above.
	C.g_dbus_connection_call(dbus, &char(portal_bus_name.str), &char(portal_object_path.str), &char(portal_iface_global_shortcuts.str), &char(method.method_name().str), payload, GVariantType(unsafe { nil }), g_dbus_call_flags_none, -1, unsafe { nil }, GCallback(voidptr(global_shortcuts_call_finished_cb)), unsafe { nil })
}

// make_payload constructs the GVariant payload expected by the portal call for
// `method`. Mirrors `Method.makePayload`. Returns `none` when there is nothing
// to send (bind_shortcuts before we have a session handle).
fn (mut self GlobalShortcuts) make_payload(method Method, request_token string) ?GVariant {
	match method {
		.create_session {
			// See the CreateSession portal docs. The payload is:
			//   ({'handle_token': <request_token>,
			//     'session_handle_token': <session_token>},)
			session_token := generate_token()
			options := variant_string_dict([
				VariantStringEntry{
					key: 'handle_token'
					value: request_token
				},
				VariantStringEntry{
					key: 'session_handle_token'
					value: session_token
				},
			])
			mut children := [options]
			return C.g_variant_new_tuple(unsafe { &children[0] }, usize(children.len))
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
			bind_type := C.g_variant_type_new(c'a(sa{sv})')
			binds := C.g_variant_builder_new(bind_type)
			C.g_variant_type_free(bind_type)

			// The bind array is built from `self.map`; the action description is
			// the action's full serialized form.
			for entry in self.map {
				details := variant_string_dict([
					VariantStringEntry{
						key: 'description'
						value: action_to_string(entry.action)
					},
					VariantStringEntry{
						key: 'preferred_trigger'
						value: entry.id
					},
				])
				mut bind_children := [C.g_variant_new_string(&char(entry.id.str)), details]
				bind := C.g_variant_new_tuple(unsafe { &bind_children[0] }, usize(bind_children.len))
				C.g_variant_builder_add_value(binds, bind)
			}
			bind_values := C.g_variant_builder_end(binds)
			C.g_variant_builder_unref(binds)

			options := variant_string_dict([
				VariantStringEntry{
					key: 'handle_token'
					value: request_token
				},
			])
			mut children := [
				C.g_variant_new_object_path(&char(self.handle.str)),
				bind_values,
				C.g_variant_new_string(c''),
				options,
			]
			return C.g_variant_new_tuple(unsafe { &children[0] }, usize(children.len))
		}
	}
}

// variant_string_dict builds an a{sv} with concrete string values wrapped in
// variants, matching glib.Variant.newParsed's `<%s>` behavior.
fn variant_string_dict(entries []VariantStringEntry) GVariant {
	dict_type := C.g_variant_type_new(c'a{sv}')
	dict := C.g_variant_builder_new(dict_type)
	C.g_variant_type_free(dict_type)
	for entry in entries {
		key := C.g_variant_new_string(&char(entry.key.str))
		value := C.g_variant_new_variant(C.g_variant_new_string(&char(entry.value.str)))
		C.g_variant_builder_add_value(dict, C.g_variant_new_dict_entry(key, value))
	}
	result := C.g_variant_builder_end(dict)
	C.g_variant_builder_unref(dict)
	return result
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
				self.activate_subscription = C.g_dbus_connection_signal_subscribe(dbus, unsafe { nil }, &char(portal_iface_global_shortcuts.str), c'Activated', &char(portal_object_path.str), &char(self.handle.str), g_dbus_signal_flags_match_arg0_path, GCallback(voidptr(global_shortcuts_activated_cb)), voidptr(self), unsafe { nil })
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
	if isnil(vardict) {
		return none
	}
	object_path_type := C.g_variant_type_new(c'o')
	value := C.g_variant_lookup_value(vardict, c'session_handle', object_path_type)
	C.g_variant_type_free(object_path_type)
	if isnil(value) {
		return none
	}
	defer {
		C.g_variant_unref(value)
	}
	mut length := usize(0)
	handle := C.g_variant_get_string(value, &length)
	if isnil(handle) || length == 0 {
		return none
	}
	return unsafe { cstring_to_vstring(handle) }
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

// global_shortcuts_call_finished_cb handles the transport-level completion of
// a portal method call. The meaningful result is delivered separately through
// the Request.Response signal.
fn global_shortcuts_call_finished_cb(source GObject, result GAsyncResult, user_data voidptr) {
	_ = user_data
	mut call_error := GError(unsafe { nil })
	params := C.g_dbus_connection_call_finish(GDBusConnection(source), result, &call_error)
	if !isnil(params) {
		C.g_variant_unref(params)
	}
	if !isnil(call_error) {
		eprintln('global shortcuts portal request failed: ${error_message(call_error)}')
		C.g_error_free(call_error)
	}
}

// global_shortcuts_responded_cb receives `(u a{sv})` from the portal request,
// clears the one-shot subscription, and dispatches a successful response to
// the method that created it.
fn global_shortcuts_responded_cb(dbus GDBusConnection, sender_name &char, object_path_ &char, interface_name &char, signal_name &char, parameters GVariant, user_data voidptr) {
	_ = sender_name
	_ = object_path_
	_ = interface_name
	_ = signal_name
	if isnil(user_data) || isnil(parameters) {
		return
	}
	mut self := unsafe { &GlobalShortcuts(user_data) }
	if self.response_subscription != 0 {
		C.g_dbus_connection_signal_unsubscribe(dbus, self.response_subscription)
		self.response_subscription = 0
	}

	response_value := C.g_variant_get_child_value(parameters, 0)
	if isnil(response_value) {
		self.has_pending_method = false
		return
	}
	response := C.g_variant_get_uint32(response_value)
	C.g_variant_unref(response_value)

	vardict := C.g_variant_get_child_value(parameters, 1)
	defer {
		if !isnil(vardict) {
			C.g_variant_unref(vardict)
		}
	}
	if response == 0 && self.has_pending_method && !isnil(vardict) {
		method := self.pending_method
		self.has_pending_method = false
		self.on_response(method, vardict)
		return
	}
	self.has_pending_method = false
	match response {
		1 {}
		2 { eprintln('global shortcuts portal request ended unexpectedly') }
		else { eprintln('global shortcuts portal returned unknown response code ${response}') }
	}
}

// global_shortcuts_activated_cb extracts the shortcut id (the second tuple
// element) and routes it through the same map lookup used by Ghostty.
fn global_shortcuts_activated_cb(dbus GDBusConnection, sender_name &char, object_path_ &char, interface_name &char, signal_name &char, parameters GVariant, user_data voidptr) {
	_ = dbus
	_ = sender_name
	_ = object_path_
	_ = interface_name
	_ = signal_name
	if isnil(user_data) || isnil(parameters) {
		return
	}
	id_value := C.g_variant_get_child_value(parameters, 1)
	if isnil(id_value) {
		return
	}
	defer {
		C.g_variant_unref(id_value)
	}
	mut length := usize(0)
	id_c := C.g_variant_get_string(id_value, &length)
	if isnil(id_c) || length == 0 {
		return
	}
	shortcut_id := unsafe { cstring_to_vstring(id_c) }
	mut self := unsafe { &GlobalShortcuts(user_data) }
	self.shortcut_activated(shortcut_id)
}

// --- Property handlers ----------------------------------------------------

fn (mut self GlobalShortcuts) set_config_reference(config &Config) {
	if self.config == config {
		return
	}
	if !isnil(self.config) {
		if !isnil(self.config.obj) {
			object_unref(self.config.obj)
		}
		self.config = unsafe { nil }
	}
	if !isnil(config) {
		if !isnil(config.obj) {
			object_ref(config.obj)
		}
		self.config = unsafe { config }
	}
}

fn (mut self GlobalShortcuts) set_dbus_reference(dbus_connection GDBusConnection) {
	if self.dbus_connection == dbus_connection {
		return
	}
	if !isnil(self.dbus_connection) {
		object_unref(self.dbus_connection)
		self.dbus_connection = unsafe { nil }
	}
	if !isnil(dbus_connection) {
		object_ref(dbus_connection)
		self.dbus_connection = dbus_connection
	}
}

// set_config sets the configuration and re-refreshes the shortcut
// registrations. Mirrors ghostty's `config` property setter + `propConfig`
// (which calls `refresh` on a "notify::config").
pub fn (mut self GlobalShortcuts) set_config(config &Config) {
	self.set_config_reference(config)
	if !isnil(self.obj) {
		C.g_object_notify_by_pspec(self.obj, g_global_shortcuts_pspec_config)
	} else {
		// Plain values are useful in unit tests; without a GObject there is no
		// notify signal to invoke propConfig.
		self.refresh()
	}
}

// set_trigger_handler connects the V wrapper equivalent of Ghostty's
// GlobalShortcuts.trigger signal.
pub fn (mut self GlobalShortcuts) set_trigger_handler(handler fn (input.Action, voidptr), user_data voidptr) {
	self.trigger_handler = handler
	self.trigger_data = user_data
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

	if !isnil(self.obj) {
		C.g_object_notify_by_pspec(self.obj, g_global_shortcuts_pspec_dbus_connection)
	}
}

// --- Signal handlers ------------------------------------------------------

// shortcut_activated is the D-Bus "Activated" signal handler. The 2nd value of
// the signal tuple is the activated shortcut id; we look up its action and emit
// our `trigger` signal. Mirrors `GlobalShortcuts.shortcutActivated`.
//
// The C signal-subscription trampoline above extracts the tuple value and
// forwards the shortcut id to this payload-processing core.
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
	if handler := self.trigger_handler {
		handler(action, self.trigger_data)
	}
	if !isnil(self.obj) {
		C.g_signal_emit_by_name(self.obj, c'trigger', &action)
	}
}

// --- Virtual methods ------------------------------------------------------

// dispose closes all connections and drops the config/dbus references. Mirrors
// the `dispose` vfunc. Ghostty closes here (not in finalize) because dropping
// references may take away access to the dbus connection.
pub fn (mut self GlobalShortcuts) dispose() {
	self.dispose_resources()
}

fn (mut self GlobalShortcuts) dispose_resources() {
	self.close()

	if !isnil(self.config) {
		if !isnil(self.config.obj) {
			object_unref(self.config.obj)
		}
		self.config = unsafe { nil }
	}
	if !isnil(self.dbus_connection) {
		object_unref(self.dbus_connection)
		self.dbus_connection = unsafe { nil }
	}
	self.trigger_handler = none
	self.trigger_data = unsafe { nil }
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
fn action_to_string(action input.Action) string {
	return action.format()
}
