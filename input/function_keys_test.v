module input

// Tests translated from ghostty src/input/function_keys.zig.

fn test_function_key_mode_source_layouts_and_ordinals() {
	assert sizeof(CursorMode) == 1
	assert [CursorMode.any, .normal, .application].map(u8(it)) == [u8(0), 1, 2]

	assert sizeof(KeypadMode) == 1
	assert [KeypadMode.any, .normal, .application].map(u8(it)) == [u8(0), 1, 2]

	assert sizeof(ModifyKeys) == 1
	assert [ModifyKeys.any, .set, .set_other].map(u8(it)) == [u8(0), 1, 2]
}

// test "keys"
// Ghostty iterates over every entry in the `keys` map and asserts that each
// key sequence fits into a termio write request small array:
//   const max = @import("../termio.zig").Message.WriteReq.Small.Max;
//   for (keys.values) |entries|
//       for (entries) |entry|
//           try testing.expect(entry.sequence.len <= max);
//
// In witty the entries are produced per-key by `get_function_key_entries`, so
// we iterate every Key value and check each produced sequence. The `max`
// constant is `MessageData(u8, 38).Small.Max` == 38 in ghostty
// (WriteReq = MessageData(u8, 38)).
fn test_keys() {
	max := 38
	for i in int(Key.unidentified) .. int(Key.paste) + 1 {
		k := unsafe { Key(i) }
		entries := get_function_key_entries(k)
		for entry in entries {
			assert entry.sequence.len <= max
		}
	}
}

// Faithful to ghostty's `kpKeys` in function_keys.zig:
//   fn kpKeys(comptime suffix) []const Entry {
//       const pc = pcStyle("\x1bO{}" ++ suffix);
//       for (pc) |*entry| entry.keypad = .application;
//       return kpDefault(suffix) ++ pc;
//   }
// So each keypad key has 16 entries: the default (mods_empty_is_any = false,
// keypad = application, sequence "\x1bO" ++ suffix) followed by the 15
// pcStyle modifier combinations (sequences "\x1bO{code}" ++ suffix with the
// modifier code = index + 2), all with keypad = application.
//
// The previous implementation dropped the 15 modifier entries, so this test
// catches that regression.
fn test_kp_keys() {
	entries := get_function_key_entries(.numpad_1)

	// 1 default + 15 modifier combinations.
	assert entries.len == 16

	// The default entry: no mods, keypad application, mods_empty_is_any false.
	def := entries[0]
	assert def.sequence == '\x1bOq'
	assert def.keypad == .application
	assert def.mods_empty_is_any == false
	assert def.mods.int() == 0

	// The 15 modifier combinations mirror the fk_modifiers table with the
	// modifier code (index + 2) embedded in the sequence.
	for i, m in fk_modifiers {
		entry := entries[i + 1]
		code := i + 2
		assert entry.sequence == '\x1bO${code}q'
		assert entry.keypad == .application
		assert entry.mods_empty_is_any
		assert entry.mods.equal(m)
	}
}

// All nonempty-modifier entries inherit Entry.mods_empty_is_any = true in
// Ghostty. Although the matcher only consults the flag for empty modifiers,
// preserving it keeps the translated entry data identical to the source.
fn test_modified_entry_defaults() {
	pc := get_function_key_entries(.arrow_up)
	assert pc[0].mods.int() != 0
	assert pc[0].mods_empty_is_any

	manual := get_function_key_entries(.backspace)
	assert manual[0].mods.int() != 0
	assert manual[0].mods_empty_is_any
}

// Confirms that the modifier keypad entries are actually reachable through
// the legacy encoder in application keypad mode. Before the fix, shift +
// numpad_1 matched no entry (only the unmodified entry existed) and produced
// no sequence.
fn test_kp_keys_encode_modified() {
	result := legacy_encode(KeyEvent{
		key: .numpad_1
		mods: Mods.init(true, false, false, false, false, false, SideInfo{})
		utf8: '1'
	}, Options{
		keypad_key_application: true
	})
	assert result == '\x1bO2q'
}
