module input

import cimgui

fn mapped_imgui_key(key Key) cimgui.Key {
	return key.imgui_key() or { panic('expected mapped ImGui key') }
}

fn test_imgui_key_mapping() {
	assert mapped_imgui_key(.key_a) == cimgui.Key.key_a
	assert mapped_imgui_key(.digit_0) == cimgui.Key.key_0
	assert mapped_imgui_key(.quote) == cimgui.Key.apostrophe
	assert mapped_imgui_key(.arrow_up) == cimgui.Key.up_arrow
	assert mapped_imgui_key(.numpad_up) == cimgui.Key.up_arrow
	assert mapped_imgui_key(.numpad_page_down) == cimgui.Key.page_up
	assert mapped_imgui_key(.numpad_begin) == cimgui.Key.tab
	assert mapped_imgui_key(.meta_right) == cimgui.Key.right_super
	assert mapped_imgui_key(.f12) == cimgui.Key.f12
	assert Key.f13.imgui_key() == none
	assert Key.unidentified.imgui_key() == none
}

// Tests translated from ghostty src/input/key.zig.

// test "ctrlOrSuper"
// Ghostty:
//   var m: Mods = ctrlOrSuper(.{});
//   try testing.expect(m.ctrlOrSuper());
// In witty, ghostty's free function `ctrlOrSuper(mods)` is `ctrl_or_super_mods`
// and the `Mods.ctrlOrSuper()` method is `Mods.ctrl_or_super()`.
fn test_ctrl_or_super() {
	m := ctrl_or_super_mods(Mods{})
	assert m.ctrl_or_super()
}

fn test_key_ctrl_or_super_uses_platform_primary_modifier() {
	$if darwin {
		assert Key.meta_left.ctrl_or_super()
		assert Key.meta_right.ctrl_or_super()
		assert !Key.control_left.ctrl_or_super()
		assert !Key.control_right.ctrl_or_super()
	} $else {
		assert Key.control_left.ctrl_or_super()
		assert Key.control_right.ctrl_or_super()
		assert !Key.meta_left.ctrl_or_super()
		assert !Key.meta_right.ctrl_or_super()
	}
}

// test "w3c"
// Ghostty:
//   // All our keys should convert to and from the W3C format.
//   inline for (@typeInfo(Key).@"enum".fields) |field| {
//       const key = @field(Key, field.name);
//       const w3c_name = key.w3c();
//       try testing.expectEqual(key, Key.fromW3C(w3c_name).?);
//   }
// V has no compile-time enum iteration, so we iterate over every Key value
// via key_name_map, which contains one entry per enum field.
fn test_w3c() {
	for _, key in key_name_map {
		w3c_name := key.w3c()
		assert key_from_w3c(w3c_name) or { panic('no w3c mapping for ${w3c_name}') } == key
	}
}

fn test_w3c_case_folding_is_ascii_only() {
	assert key_from_w3c('INSERT')? == .insert
	assert key_from_w3c('İnsert') == none
}
