module input

// Tests translated from ghostty src/input/command.zig.

// test "command defaults"
// Ghostty:
//   try testing.expect(defaults.len > 0);
//   try testing.expectEqual(defaults.len, defaultsC.len);
// The second assertion compares against `defaultsC`, the C-ABI (Command.C)
// form of `defaults` built via `comptimeCval()`. That C-ABI representation is
// not modeled in witty (no cval), and in ghostty it is defined as
// `[defaults.len]Command.C`, making `defaults.len == defaultsC.len` a
// tautology by construction. The meaningful assertion — that the default
// command set is analyzed and non-empty — is translated faithfully here.
fn test_command_defaults() {
	assert command_defaults.len > 0
}
