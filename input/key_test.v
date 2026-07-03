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
