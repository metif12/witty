module input

// Tests translated from ghostty src/input/function_keys.zig.

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
