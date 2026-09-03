module highlight

// Additional highlight types and methods not covered by highlight.v.
//
// Source: highlight.zig (213 lines)
//
// This file contains types and methods that were missing from the
// initial highlight.v translation:
//
// 1. TrackedHighlight.init_assume() - creates a tracked highlight
//    from pre-tracked pins without the overhead of tracking.
//
// 2. FlattenedHighlight.from_pins() - creates a flattened highlight
//    from start/end pins by iterating through page chunks.

import terminal

// init_assume initializes a tracked highlight by assuming that the
// provided pins are already tracked. This allows callers to perform
// tracked operations without the overhead of tracking the pins, if
// the caller can guarantee that the pins are already tracked or that
// the terminal state will not change.
//
// Do not call deinit on highlights created with this function.
pub fn TrackedHighlight.init_assume(start &terminal.PagePin, end &terminal.PagePin) TrackedHighlight {
	return TrackedHighlight{
		start: start
		end: end
	}
}

// from_pins creates a FlattenedHighlight from start and end pins by
// iterating through the page list and collecting all chunks between
// the two pins.
//
pub fn FlattenedHighlight.from_pins(start terminal.PagePin, end terminal.PagePin) FlattenedHighlight {
	mut chunks := []Chunk{}
	mut iterator := start.page_iterator(.right_down, end)
	for {
		chunk := iterator.next() or { break }
		chunks << Chunk{
			node: chunk.node
			serial: chunk.node.serial
			start: chunk.start
			end: chunk.end
		}
	}
	return FlattenedHighlight{
		chunks: chunks
		top_x: start.x
		bot_x: end.x
	}
}
