module source_file_writer

import io

// Zig 0.15.2 std.Io.Writer.writeAll.
pub fn write_all(mut writer io.Writer, data []u8) ! {
	mut index := 0
	for index < data.len {
		count := writer.write(data[index..]) or { return error('WriteFailed') }
		index += count
	}
}
