module terminfo

// Ports of the two tests in ghostty/src/terminfo/Source.zig.

fn test_xtgettcap_map() {
	src := Source{
		names: [
			'ghostty',
			'xterm-ghostty',
			'Ghostty',
		]
		capabilities: [
			Capability{ name: 'am', value: CapabilityValue.boolean() },
			Capability{ name: 'colors', value: CapabilityValue.numeric(256) },
			Capability{ name: 'kx', value: CapabilityValue.string('^?') },
			Capability{ name: 'kbs', value: CapabilityValue.string('^H') },
			Capability{ name: 'kf1', value: CapabilityValue.string('\\EOP') },
			Capability{ name: 'Smulx', value: CapabilityValue.string('\\E[4:%p1%dm') },
		]
	}

	m := src.xtgettcap_map()
	assert m[hexencode('am')] == '\x1bP1+r616D\x1b\\'
	assert m[hexencode('kx')] == '\x1bP1+r6B78=7F\x1b\\'
	assert m[hexencode('kbs')] == '\x1bP1+r6B6273=08\x1b\\'
	assert m[hexencode('kf1')] == '\x1bP1+r6B6631=1B4F50\x1b\\'
	assert m[hexencode('Smulx')] == '\x1bP1+r536D756C78=5C455B343A25703125646D\x1b\\'
}

fn test_encode() {
	src := Source{
		names: [
			'ghostty',
			'xterm-ghostty',
			'Ghostty',
		]
		capabilities: [
			Capability{ name: 'am', value: CapabilityValue.boolean() },
			Capability{ name: 'ccc', value: CapabilityValue.canceled() },
			Capability{ name: 'colors', value: CapabilityValue.numeric(256) },
			Capability{ name: 'bel', value: CapabilityValue.string('^G') },
		]
	}

	expected := 'ghostty|xterm-ghostty|Ghostty,\n' + '\tam,\n' + '\tccc@,\n' +
		'\tcolors#256,\n' + '\tbel=^G,\n'
	assert src.encode() == expected
}

// The translated entry must keep the source's names, ordering and size.
fn test_ghostty_terminfo_entry_matches_source() {
	assert ghostty.names == ['xterm-ghostty', 'ghostty', 'Ghostty']
	assert ghostty.capabilities.len == 268

	// Spot-check one of each value kind, in source order.
	assert ghostty.capabilities[0].name == 'am'
	assert ghostty.capabilities[0].value.tag == .boolean

	mut numeric_count := 0
	mut string_count := 0
	mut boolean_count := 0
	for cap in ghostty.capabilities {
		match cap.value.tag {
			.numeric { numeric_count++ }
			.string { string_count++ }
			.boolean { boolean_count++ }
			.canceled { assert false, 'no canceled capability in the source entry' }
		}
	}
	assert boolean_count == 15
	assert numeric_count == 5
	assert string_count == 248

	// The encoded entry starts with the name line and the first capability.
	encoded := ghostty.encode()
	assert encoded.starts_with('xterm-ghostty|ghostty|Ghostty,\n\tam,\n')
	assert encoded.ends_with(',\n')
}
