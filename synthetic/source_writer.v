module synthetic

import io

// std.Io.Writer.fixed/fixedDrain: preserve the prefix on WriteFailed.
pub struct FixedWriter {
pub mut:
	buffer []u8
	end    int
}

pub fn (mut writer FixedWriter) write(data []u8) !int {
	count := if data.len < writer.buffer.len - writer.end {
		data.len
	} else {
		writer.buffer.len - writer.end
	}
	for i in 0 .. count {
		writer.buffer[writer.end + i] = data[i]
	}
	writer.end += count
	if count < data.len { return error('WriteFailed') }
	return count
}

struct CollectingWriter {
mut:
	data []u8
}

fn (mut writer CollectingWriter) write(data []u8) !int {
	writer.data << data
	return data.len
}

// std.Io.Writer.writeAll; error timing remains at each source write operation.
fn source_write_all(mut writer io.Writer, data []u8) ! {
	mut index := 0
	for index < data.len {
		count := writer.write(data[index..]) or { return error('WriteFailed') }
		index += count
	}
}

fn source_url_percent_encode(mut writer io.Writer, data []u8) ! {
	hex := '0123456789ABCDEF'
	mut start := 0
	for index, byte in data {
		if byte >= 0x20 && byte <= 0x7e && byte !in [` `, `;`, `=`] { continue
		 }
		source_write_all(mut writer, data[start..index])!
		source_write_all(mut writer, '%'.bytes())!
		source_write_all(mut writer, [hex[int(byte >> 4)], hex[int(byte & 15)]])!
		start = index + 1
	}
	source_write_all(mut writer, data[start..])!
}
