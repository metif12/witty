module gtk

// ext_actions_linux.v - GAction / GActionMap helpers.
//
// Translated from ghostty/src/apprt/gtk/ext/actions.zig.
//
// The Zig original provides:
//   * gActionNameIsValid  - a comptime-friendly reimplementation of
//                           g_action_name_is_valid().
//   * Action(T)           - a generic struct describing an action (name,
//                           callback, parameter type, optional state).
//   * add / addToMap      - register a set of actions on a gio.ActionMap.
//   * addAsGroup          - collect actions into a SimpleActionGroup and insert
//                           it into a widget under a prefix.
//
// V has no generics-over-widget-type the way Zig does here, and the action
// callbacks are C trampolines tied to specific widget classes (out of scope).
// We keep `action_name_is_valid` faithfully (pure logic) and translate the
// GAction/GActionMap plumbing against `voidptr` handles, declaring the new C
// functions this file needs.

// --- Opaque handle aliases (module-local) ---------------------------------
// These GIO action types are not declared in the shared bindings.

// GSimpleAction is a gio.SimpleAction*.
pub type GSimpleAction = voidptr

// GAction is a gio.Action* (interface).
pub type GAction = voidptr

// GActionMap is a gio.ActionMap* (interface).
pub type GActionMap = voidptr

// GActionGroup is a gio.ActionGroup* (interface).
pub type GActionGroup = voidptr

// GSimpleActionGroup is a gio.SimpleActionGroup*.
pub type GSimpleActionGroup = voidptr

// GVariantType is a glib.VariantType*.
pub type GVariantType = voidptr

// GCallback is a plain C callback function pointer.
pub type GCallback = voidptr

// --- New C bindings -------------------------------------------------------

fn C.g_simple_action_new(name &char, parameter_type GVariantType) GSimpleAction
fn C.g_simple_action_new_stateful(name &char, parameter_type GVariantType, state GVariant) GSimpleAction
fn C.g_action_map_add_action(action_map GActionMap, action GAction)
fn C.g_simple_action_group_new() GSimpleActionGroup
fn C.g_signal_connect_data(instance voidptr, detailed_signal &char, c_handler GCallback, data voidptr, destroy_data voidptr, connect_flags int) u64
fn C.gtk_widget_insert_action_group(widget GtkWidget, name &char, group GActionGroup)

// --- Action name validation -----------------------------------------------

// action_name_is_valid checks that an action name is valid.
//
// Faithful reimplementation of `g_action_name_is_valid()` (see
// gActionNameIsValid in the Zig original). An action name must be non-empty and
// contain only '-', '.', digits, and ASCII letters.
//
// See: https://docs.gtk.org/gio/type_func.Action.name_is_valid.html
pub fn action_name_is_valid(name string) bool {
	if name.len == 0 {
		return false
	}
	for c in name {
		match true {
			c == `-` { continue }
			c == `.` { continue }
			c >= `0` && c <= `9` { continue }
			c >= `a` && c <= `z` { continue }
			c >= `A` && c <= `Z` { continue }
			else { return false }
		}
	}
	return true
}

// --- Action descriptor ----------------------------------------------------

// Action describes a single GAction to be registered.
//
// Faithful in shape to the Zig `Action(T)` struct. Zig parameterizes this on
// the owning widget type `T` (for a typed callback and `self` pointer); V has
// no such generic-over-widget mechanism, so `callback` is a plain C callback
// and `self` is passed alongside at registration time.
pub struct Action {
pub:
	name           string
	callback       GCallback
	parameter_type GVariantType = unsafe { nil }
	state          GVariant     = unsafe { nil }
}

// new initializes a new action, checking that the name is valid. Mirrors
// `Action.init`. In Zig the name check is a comptime assert; here it panics at
// call time on an invalid name (still a programming error).
pub fn Action.new(name string, callback GCallback, parameter_type GVariantType) Action {
	if !action_name_is_valid(name) {
		panic('invalid action name: ${name}')
	}
	return Action{
		name: name
		callback: callback
		parameter_type: parameter_type
	}
}

// new_stateful initializes a new stateful action. Mirrors `Action.initStateful`.
pub fn Action.new_stateful(name string, callback GCallback, parameter_type GVariantType, state GVariant) Action {
	if !action_name_is_valid(name) {
		panic('invalid action name: ${name}')
	}
	return Action{
		name: name
		callback: callback
		parameter_type: parameter_type
		state: state
	}
}

// --- Registration ---------------------------------------------------------

// add_to_map adds the given actions to a gio.ActionMap, connecting each
// action's "activate" signal to its callback with `self` as user data. Mirrors
// `addToMap`.
pub fn add_to_map(self voidptr, action_map GActionMap, actions []Action) {
	for entry in actions {
		if !action_name_is_valid(entry.name) {
			panic('invalid action name: ${entry.name}')
		}
		name := &char(entry.name.str)
		action := if !isnil(entry.state) {
			C.g_simple_action_new_stateful(name, entry.parameter_type, entry.state)
		} else {
			C.g_simple_action_new(name, entry.parameter_type)
		}
		C.g_signal_connect_data(action, c'activate', entry.callback, self, unsafe { nil },
			0)
		C.g_action_map_add_action(action_map, action)
		// Ghostty defers action.unref() here; the map holds its own ref.
		object_unref(action)
	}
}

// add_as_group collects the given actions into a new SimpleActionGroup and
// inserts it into the widget under `name`. Returns the group. Mirrors
// `addAsGroup`.
//
// In Zig `self` implements gtk.Widget via `self.as(gtk.Widget)`; here the
// caller passes the widget directly.
pub fn add_as_group(self voidptr, widget GtkWidget, name string, actions []Action) GSimpleActionGroup {
	if !action_name_is_valid(name) {
		panic('invalid action group name: ${name}')
	}
	group := C.g_simple_action_group_new()
	add_to_map(self, GActionMap(group), actions)
	C.gtk_widget_insert_action_group(widget, &char(name.str), GActionGroup(group))
	return group
}
