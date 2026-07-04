module input

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
