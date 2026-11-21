module synthetic

import io

// src/synthetic/Generator.zig. All production generation uses the caller's
// writer; the owned-slice next method is retained as a compatibility adapter.
pub interface Generator {
mut:
	next_writer(mut writer io.Writer, max_len uint) !
	next(max_len uint) ![]u8
}
