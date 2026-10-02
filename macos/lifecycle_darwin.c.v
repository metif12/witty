@[has_globals]
module macos

__global (
	g_application_has_become_active bool
	g_update_is_installing bool
)

pub fn set_update_is_installing(installing bool) {
	g_update_is_installing = installing
}

pub fn application_has_become_active() bool {
	return g_application_has_become_active
}

pub fn termination_requires_confirmation(core_needs_confirm bool) bool {
	windows := msg_id(shared_app(), 'windows')
	count := int(msg_u64(windows, 'count'))
	mut visible := false
	for i in 0 .. count {
		if msg_bool(msg_id_u64(windows, 'objectAtIndex:', u64(i)), 'isVisible') {
			visible = true
			break
		}
	}
	manager := msg_id(get_class('NSAppleEventManager'), 'sharedAppleEventManager')
	event := msg_id(manager, 'currentAppleEvent')
	why := msg_id_u64(event, 'attributeDescriptorForKeyword:', u64(0x7768793f))
	return should_confirm_termination(count, visible, g_update_is_installing,
		u32(msg_u64(why, 'typeCodeValue')), core_needs_confirm)
}
