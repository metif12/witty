module vaxis

// Loop.ttyRun's fixed POSIX read buffer. Keep the pinned source's incomplete
// sequence offset (+1) and its read-count boundary rather than combining the
// prefix length with the next read's byte count.
struct LoopReadBuffer {
mut:
	buf        [1024]u8
	read_start int
	seq_start  int
	count      int
}

fn (mut reader LoopReadBuffer) read_buffer() []u8 {
	assert reader.read_start <= reader.buf.len
	return unsafe { (&reader.buf[0] + reader.read_start).vbytes(reader.buf.len - reader.read_start) }
}

fn (mut reader LoopReadBuffer) begin_read(count usize) {
	reader.count = int(count)
	reader.seq_start = 0
}

fn (reader &LoopReadBuffer) has_next() bool {
	return reader.seq_start < reader.count
}

fn (mut reader LoopReadBuffer) parse_next(mut parser Parser, clipboard bool) !ParserResult {
	assert reader.has_next()
	input := unsafe { (&reader.buf[0] + reader.seq_start).vbytes(reader.count - reader.seq_start) }
	result := parser.parse(input, clipboard)!
	if result.n == 0 {
		initial_start := reader.seq_start
		for reader.seq_start < reader.count {
			reader.buf[reader.seq_start - initial_start] = reader.buf[reader.seq_start]
			reader.seq_start++
		}
		reader.read_start = reader.seq_start - initial_start + 1
	} else {
		reader.read_start = 0
		reader.seq_start += int(result.n)
	}
	return result
}
