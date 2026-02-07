module terminal

// Translated from ghostty/src/terminal/device_status.zig

// An enum of the available device status requests.
//
// In Zig this is a comptime-generated enum(u16) where the tag packs the
// value and question bit into a u16 using a packed struct. In V we represent
// it as a regular enum and provide from_int/to_tag helpers.
pub enum DeviceStatusRequest {
	operating_status   // value=5, question=false
	cursor_position    // value=6, question=false
	color_scheme       // value=996, question=true
}

// The tag type for our enum is a u16 but we use a struct
// in order to pack the question bit into the tag. The "u16" size is
// chosen somewhat arbitrarily to match the largest expected size
// we see as a multiple of 8 bits.
//
// Layout: bits 0-14 are the value (u15), bit 15 is the question flag.
pub struct DeviceStatusTag {
pub:
	value    u16
	question bool
}

// Pack a DeviceStatusTag into a u16.
// Bit 15 = question, bits 0-14 = value.
pub fn (self &DeviceStatusTag) to_u16() u16 {
	q := if self.question { u16(1) << 15 } else { u16(0) }
	return (self.value & 0x7FFF) | q
}

// Unpack a u16 into a DeviceStatusTag.
pub fn DeviceStatusTag.from_u16(v u16) DeviceStatusTag {
	return DeviceStatusTag{
		value: v & 0x7FFF
		question: (v >> 15) & 1 == 1
	}
}

// A single entry of a possible device status request we support. The
// "question" field determines if it is valid with or without the "?"
// prefix.

// The full list of device status request entries.
// (In Zig these are comptime constants used to generate the enum.)

// Build a DeviceStatusRequest from a numeric value and question flag,
// or return none if the combination is not recognized.
pub fn DeviceStatusRequest.from_int(v u16, question bool) ?DeviceStatusRequest {
	if v == 5 && !question {
		return .operating_status
	}
	if v == 6 && !question {
		return .cursor_position
	}
	if v == 996 && question {
		return .color_scheme
	}
	return none
}

// Returns the DeviceStatusTag for a given request.
pub fn (self DeviceStatusRequest) tag() DeviceStatusTag {
	return match self {
		.operating_status {
			DeviceStatusTag{ value: 5, question: false }
		}
		.cursor_position {
			DeviceStatusTag{ value: 6, question: false }
		}
		.color_scheme {
			DeviceStatusTag{ value: 996, question: true }
		}
	}
}
