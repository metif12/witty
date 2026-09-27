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
			Capability{ name: 'am', value: CapabilityValueBoolean{} },
			Capability{ name: 'colors', value: CapabilityValueNumeric{ value: 256 } },
			Capability{ name: 'kx', value: CapabilityValueString{ value: '^?' } },
			Capability{ name: 'kbs', value: CapabilityValueString{ value: '^H' } },
			Capability{ name: 'kf1', value: CapabilityValueString{ value: '\\EOP' } },
			Capability{ name: 'Smulx', value: CapabilityValueString{ value: '\\E[4:%p1%dm' } },
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
			Capability{ name: 'am', value: CapabilityValueBoolean{} },
			Capability{ name: 'ccc', value: CapabilityValueCanceled{} },
			Capability{ name: 'colors', value: CapabilityValueNumeric{ value: 256 } },
			Capability{ name: 'bel', value: CapabilityValueString{ value: '^G' } },
		]
	}

	expected := 'ghostty|xterm-ghostty|Ghostty,\n' + '\tam,\n' + '\tccc@,\n' +
		'\tcolors#256,\n' + '\tbel=^G,\n'
	assert src.encode() == expected
}

// The translated entry must keep the source's names, ordering and size.
fn test_ghostty_terminfo_entry_matches_source() {
	assert sizeof(CapabilityValueTag) == 1
	assert u8(CapabilityValueTag.canceled) == 0
	assert u8(CapabilityValueTag.boolean) == 1
	assert u8(CapabilityValueTag.numeric) == 2
	assert u8(CapabilityValueTag.string) == 3
	assert ghostty.names == ['xterm-ghostty', 'ghostty', 'Ghostty']
	assert ghostty.capabilities.len == 268

	// Spot-check one of each value kind, in source order.
	assert ghostty.capabilities[0].name == 'am'
	assert ghostty.capabilities[0].value is CapabilityValueBoolean
	assert ghostty.capabilities[0].value.tag() == .boolean

	mut numeric_count := 0
	mut string_count := 0
	mut boolean_count := 0
	for cap in ghostty.capabilities {
		match cap.value {
			CapabilityValueNumeric { numeric_count++ }
			CapabilityValueString { string_count++ }
			CapabilityValueBoolean { boolean_count++ }
			CapabilityValueCanceled { assert false, 'no canceled capability in the source entry' }
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
