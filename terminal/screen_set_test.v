module terminal

fn test_screen_key_storage() {
	assert $sizeof(ScreenKey) == 1
	assert u8(ScreenKey.primary) == 0
	assert u8(ScreenKey.alternate) == 1
}

fn test_screen_set() {
	mut set := ScreenSet.init(ScreenOptions{
		cols: 80
		rows: 24
	}) or {
		assert false, err.msg()
		return
	}
	defer { set.deinit() }
	assert set.active_key == .primary

	_ = set.get_init(.alternate, ScreenOptions{
		cols: 80
		rows: 24
	}) or {
		assert false, err.msg()
		return
	}
	set.switch_to(.alternate)
	assert set.active_key == .alternate
}
