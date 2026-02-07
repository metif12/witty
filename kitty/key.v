module kitty

// Kitty keyboard protocol support.
//
// Source: kitty/key.zig
//
// The Kitty keyboard protocol allows terminal applications to receive
// enhanced keyboard input, including key disambiguation, event reporting,
// alternate key reporting, and associated text reporting.

// ============================================================
// Flags - possible flags for the Kitty keyboard protocol
// ============================================================

// The possible flags for the Kitty keyboard protocol. These are
// represented as individual booleans rather than a packed struct
// since V doesn't support packed structs with bitcasting.
pub struct KeyFlags {
pub mut:
	disambiguate      bool
	report_events     bool
	report_alternates bool
	report_all        bool
	report_associated bool
}

// Kitty keyboard protocol disabled (all flags off).
pub const key_flags_disabled = KeyFlags{}

// All modes on.
pub const key_flags_all = KeyFlags{
	disambiguate: true
	report_events: true
	report_alternates: true
	report_all: true
	report_associated: true
}

// Convert flags to a u5 integer representation. The bit layout is:
// bit 0: disambiguate
// bit 1: report_events
// bit 2: report_alternates
// bit 3: report_all
// bit 4: report_associated
pub fn (self KeyFlags) int_val() u8 {
	mut result := u8(0)
	if self.disambiguate {
		result |= 0b00001
	}
	if self.report_events {
		result |= 0b00010
	}
	if self.report_alternates {
		result |= 0b00100
	}
	if self.report_all {
		result |= 0b01000
	}
	if self.report_associated {
		result |= 0b10000
	}
	return result
}

// Create flags from a u5 integer representation.
pub fn KeyFlags.from_int(v u8) KeyFlags {
	return KeyFlags{
		disambiguate: (v & 0b00001) != 0
		report_events: (v & 0b00010) != 0
		report_alternates: (v & 0b00100) != 0
		report_all: (v & 0b01000) != 0
		report_associated: (v & 0b10000) != 0
	}
}

// ============================================================
// SetMode - the possible modes for setting the key flags
// ============================================================

// The possible modes for setting the key flags via the CSI = u sequence.
pub enum KeySetMode {
	// Replace the current flags with the new value.
	set_
	// Bitwise OR the new flags into the current flags.
	or_
	// Bitwise AND NOT the new flags from the current flags (clear bits).
	not_
}

// ============================================================
// FlagStack - stack for the key flags
// ============================================================

// Stack for the key flags. This implements the push/pop behavior
// of the CSI > u and CSI < u sequences. We implement the stack as
// fixed size to avoid heap allocation.
pub struct KeyFlagStack {
pub mut:
	flags [8]KeyFlags = [8]KeyFlags{init: key_flags_disabled}
	idx   u8
}

// Return the current stack value.
pub fn (self KeyFlagStack) current() KeyFlags {
	return self.flags[self.idx]
}

// Perform the "set" operation as described in the spec for
// the CSI = u sequence.
pub fn (mut self KeyFlagStack) set(mode KeySetMode, v KeyFlags) {
	match mode {
		.set_ {
			self.flags[self.idx] = v
		}
		.or_ {
			self.flags[self.idx] = KeyFlags.from_int(self.flags[self.idx].int_val() | v.int_val())
		}
		.not_ {
			self.flags[self.idx] = KeyFlags.from_int(self.flags[self.idx].int_val() & ~v.int_val())
		}
	}
}

// Push a new set of flags onto the stack. If the stack is full
// then the oldest entry is evicted (wraps around).
pub fn (mut self KeyFlagStack) push(flags KeyFlags) {
	// Overflow and wrap around if we're full, which evicts
	// the oldest entry.
	self.idx = (self.idx + 1) % 8
	self.flags[self.idx] = flags
}

// Pop `n` entries from the stack. This will just wrap around
// if `n` is greater than the amount in the stack.
pub fn (mut self KeyFlagStack) pop(n int) {
	// If n is more than our length then we just reset the stack.
	// This also avoids a DoS vector where a malicious client
	// could send a huge number of pop commands to waste cpu.
	if n >= 8 {
		self.idx = 0
		self.flags = [8]KeyFlags{init: key_flags_disabled}
		return
	}

	for _ in 0 .. n {
		self.flags[self.idx] = key_flags_disabled
		// Wrapping decrement
		if self.idx == 0 {
			self.idx = 7
		} else {
			self.idx -= 1
		}
	}
}
