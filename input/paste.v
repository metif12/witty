module input

import terminal

// PasteOptions contains options that affect paste encoding.
pub struct PasteOptions {
pub:
	// True if bracketed paste mode is on.
	bracketed bool
}

// PasteEncodeResult retains the source's three slices as named fields. The
// pinned V compiler generates invalid C for a fixed array inside an error
// union, so the public lib_vt boundary rebuilds the source-shaped array.
pub struct PasteEncodeResult {
pub:
	prefix string
	data   string
	suffix string
}

pub fn (self PasteEncodeResult) parts() [3]string {
	return [self.prefix, self.data, self.suffix]!
}

// from_terminal returns the encoding options for the current terminal state.
pub fn PasteOptions.from_terminal(t &terminal.Terminal) PasteOptions {
	return PasteOptions{
		bracketed: t.modes.get(.bracketed_paste)
	}
}

// paste_encode encodes immutable data for pasting. As in Ghostty, an
// unbracketed newline requires the caller to make a mutable copy and retry.
pub fn paste_encode(data string, opts PasteOptions) !PasteEncodeResult {
	if opts.bracketed {
		return PasteEncodeResult{
			prefix: '\x1b[200~'
			data: data
			suffix: '\x1b[201~'
		}
	}
	if data.contains('\n') {
		return error('MutableRequired')
	}
	return PasteEncodeResult{ data: data }
}

// paste_encode_mut is the mutable-input specialization of Ghostty's generic
// paste.encode. It rewrites newlines in place when bracketed paste is off.
pub fn paste_encode_mut(mut data []u8, opts PasteOptions) PasteEncodeResult {
	if opts.bracketed {
		return PasteEncodeResult{
			prefix: '\x1b[200~'
			data: data.bytestr()
			suffix: '\x1b[201~'
		}
	}
	for i, byte in data {
		if byte == `\n` {
			data[i] = u8(`\r`)
		}
	}
	return PasteEncodeResult{
		data: data.bytestr()
	}
}

// paste_is_safe returns true if data does not contain a newline or a
// bracketed-paste end fencepost.
pub fn paste_is_safe(data string) bool {
	return !data.contains('\n') && !data.contains('\x1b[201~')
}
