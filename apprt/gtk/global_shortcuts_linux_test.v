module gtk

import configpkg
import input

fn test_global_shortcuts_refreshes_map_from_config_bindings() {
	mut inner := configpkg.Config{}
	inner.keybind.parse_cli('ctrl+x=ignore')!
	inner.keybind.parse_cli('global:ctrl+shift+a=new_window')!
	inner.keybind.parse_cli('global:ctrl+b=ignore')!
	inner.keybind.parse_cli('chain=new_window')!
	mut cfg := config_new(inner)
	mut shortcuts := GlobalShortcuts{
		config: cfg
	}

	shortcuts.refresh()

	assert shortcuts.map.len == 1
	assert shortcuts.map[0].id == 'SHIFT+CTRL+a'
	assert shortcuts.map[0].action == input.Action(input.ActionNewWindow{})
	assert shortcuts.action_for_id('SHIFT+CTRL+a') or { input.Action{} } == input.Action(input.ActionNewWindow{})
	assert shortcuts.action_for_id('CTRL+x') == none

	shortcuts.dispose()
	cfg.unref()
}

fn test_global_shortcut_action_description_uses_full_action_format() {
	action := input.Action.parse('text:hello world')!
	assert action_to_string(action) == 'text:hello world'
}

fn test_global_shortcut_portal_payload_types() {
	mut shortcuts := GlobalShortcuts{}
	create_payload := shortcuts.make_payload(.create_session, 'ghostty_1234567') or {
		assert false, 'expected create-session payload'
		return
	}
	assert unsafe { cstring_to_vstring(C.g_variant_get_type_string(create_payload)) } == '(a{sv})'
	C.g_variant_unref(create_payload)

	shortcuts.handle = '/org/freedesktop/portal/desktop/session/1_2/ghostty_7654321'
	shortcuts.map = [ShortcutMapEntry{
		id: 'CTRL+a'
		action: input.Action.parse('text:hello')!
	}]
	bind_payload := shortcuts.make_payload(.bind_shortcuts, 'ghostty_1234567') or {
		assert false, 'expected bind-shortcuts payload'
		return
	}
	assert unsafe { cstring_to_vstring(C.g_variant_get_type_string(bind_payload)) } == '(oa(sa{sv})sa{sv})'
	C.g_variant_unref(bind_payload)
}

fn test_global_shortcut_session_handle_lookup() {
	dict_type := C.g_variant_type_new(c'a{sv}')
	dict_builder := C.g_variant_builder_new(dict_type)
	C.g_variant_type_free(dict_type)
	key := C.g_variant_new_string(c'session_handle')
	path := '/org/freedesktop/portal/desktop/session/1_2/ghostty_1234567'
	value := C.g_variant_new_variant(C.g_variant_new_object_path(&char(path.str)))
	C.g_variant_builder_add_value(dict_builder, C.g_variant_new_dict_entry(key, value))
	dict := C.g_variant_builder_end(dict_builder)
	C.g_variant_builder_unref(dict_builder)

	shortcuts := GlobalShortcuts{}
	assert shortcuts.lookup_session_handle(dict) or { '' } == path
	C.g_variant_unref(dict)
}

fn record_global_shortcut(action input.Action, user_data voidptr) {
	if !isnil(user_data) {
		mut received := unsafe { &input.Action(user_data) }
		unsafe {
			*received = action
		}
	}
}

fn test_global_shortcut_trigger_handler_receives_action() {
	mut received := input.Action(input.ActionIgnore{})
	mut shortcuts := GlobalShortcuts{
		map: [ShortcutMapEntry{
			id: 'CTRL+n'
			action: input.ActionNewWindow{}
		}]
	}
	shortcuts.set_trigger_handler(record_global_shortcut, voidptr(&received))
	shortcuts.shortcut_activated('CTRL+n')
	assert received == input.Action(input.ActionNewWindow{})
}
