module input

// Tests translated from ghostty src/input/command.zig.

// test "command defaults"
// Ghostty:
//   try testing.expect(defaults.len > 0);
//   try testing.expectEqual(defaults.len, defaultsC.len);
fn test_command_defaults() {
	assert command_defaults.len > 0
	assert command_defaults.len == command_defaults_c.len
	assert action_tags().len == 83
	assert command_defaults.len == 88
	for i in 1 .. command_defaults.len {
		assert !command_defaults[i].less_than(command_defaults[i - 1])
	}
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

fn test_command_clone_duplicates_owned_payloads() {
	original := Command{
		action: Action.new_str(.text, 'payload'.clone())
		title: 'Title'.clone()
		description: 'Description'.clone()
	}
	cloned := original.clone()
	assert cloned.equal(original)
	assert cloned.action.str_param.str != original.action.str_param.str
	assert cloned.title.str != original.title.str
	assert cloned.description.str != original.description.str
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
