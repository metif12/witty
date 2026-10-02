module pty

// Redeclare this winsize struct so we can just use a V struct. This
// layout should be correct on all tested platforms. The defaults on this
// are some reasonable screen size but you should probably not use them.
pub struct Winsize {
pub mut:
	ws_row    u16 = 100
	ws_col    u16 = 80
	ws_xpixel u16 = 800
	ws_ypixel u16 = 600
}

// The modes of a pty. Not all of these modes are supported on
// all platforms but all platforms share the same mode struct.
//
// The default values of fields in this struct are set to the
// most typical values for a pty. This makes it easier for cross-platform
// code which doesn't support all of the modes to work correctly.
pub struct Mode {
mut:
	value u8 = 0b11
}

pub fn Mode.init(canonical bool, echo bool) Mode {
	return Mode{
		value: u8(canonical) | (u8(echo) << 1)
	}
}

// canonical reports the ICANON POSIX mode. When set, input is processed line
// by line.
pub fn (self Mode) canonical() bool {
	return self.value & 0b01 != 0
}

// echo reports the ECHO POSIX mode. When set, input characters are echoed
// back.
pub fn (self Mode) echo() bool {
	return self.value & 0b10 != 0
}
