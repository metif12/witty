module vaxis

// Byte spans from the pinned unicode.zig wrapper. The supplied text remains
// owned by the caller, as it does for the source's []const u8 slices.
pub struct Grapheme {
pub mut:
	start uint @[required]
	len   uint @[required]
}

pub fn (grapheme Grapheme) bytes(text string) string {
	if grapheme.len > ~uint(0) - grapheme.start { panic('integer overflow') }
	byte_limit := grapheme.start + grapheme.len
	if byte_limit > uint(text.len) { panic('index out of bounds') }
	return text.substr_unsafe(int(grapheme.start), int(byte_limit))
}

// The decoder state stays private; init supplies both source-required iterator
// components rather than permitting a partially initialized public value.
@[noinit]
pub struct GraphemeIterator {
mut:
	inner TextInputGraphemeIterator
}

pub fn GraphemeIterator.init(text string) GraphemeIterator {
	return GraphemeIterator{
		inner: text_input_grapheme_iterator(text)
	}
}

pub fn grapheme_iterator(text string) GraphemeIterator {
	return GraphemeIterator.init(text)
}

pub fn (mut iter GraphemeIterator) next() ?Grapheme {
	span := iter.inner.next() or { return none }
	return Grapheme{
		start: uint(span.start)
		len:   uint(span.limit - span.start)
	}
}
