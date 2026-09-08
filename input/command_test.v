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

fn test_command_equal_compares_source_fields() {
	base := Command{
		action: Action.new(.reset)
		title: 'Reset Terminal'
		description: 'Reset the terminal to a clean state.'
	}
	assert base.equal(base.clone())
	assert !base.equal(Command{
		...base
		action: Action.new(.quit)
	})
	assert !base.equal(Command{
		...base
		title: 'Reset'
	})
	assert !base.equal(Command{
		...base
		description: ''
	})
}

fn test_command_defaults_preserve_signed_move_tab_offsets() {
	left := command_defaults.filter(it.title == 'Move Tab Left')
	right := command_defaults.filter(it.title == 'Move Tab Right')
	assert left.len == 1
	assert right.len == 1
	assert left[0].action.int_param == -1
	assert right[0].action.int_param == 1
	assert left[0].action.format() == 'move_tab:-1'
	assert right[0].action.format() == 'move_tab:1'
}
