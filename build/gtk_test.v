module build

fn test_targets_packed_layout_matches_ghostty() {
	assert sizeof(Targets) == 1
	assert Targets{}.int_val() == 0
	assert Targets.init(true, false).int_val() == 0x01
	assert Targets.init(false, true).int_val() == 0x02
	both := Targets.init(true, true)
	assert both.int_val() == 0x03
	assert both.x11()
	assert both.wayland()
}

fn test_targets_from_pkg_config_output() {
	assert targets_from_output('x11 wayland').int_val() == 0x03
	assert targets_from_output('wayland').int_val() == 0x02
	assert targets_from_output('x11').int_val() == 0x01
	assert targets_from_output('').int_val() == 0
}
