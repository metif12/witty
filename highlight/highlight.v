module highlight

// Highlight types for search results and selections.
//
// Source: terminal/highlight.zig
// This module provides three representations of highlights:
// - FlattenedHighlight: pre-computed, efficient to render, no terminal lock needed
// - UntrackedHighlight: simple start/end pins, may become invalid on page changes
// - TrackedHighlight: tracked pins that auto-update on page modifications

import terminal

// ============================================================
// Chunk
// ============================================================

// Chunk represents a contiguous range of rows within a single page node
// that is part of a highlight. Multiple chunks form a full highlight
// when it spans across page boundaries.
pub struct Chunk {
pub mut:
	// The page node this chunk belongs to.
	node &terminal.PageNode = unsafe { nil }
	// The serial number of the node at the time the chunk was created.
	// Used to detect if the node has been recycled.
	serial u64
	// Start row index (inclusive).
	start u16
	// End row index (exclusive).
	end u16
}

// ============================================================
// FlattenedHighlight
// ============================================================

// FlattenedHighlight is a pre-computed highlight that contains all
// information needed to render without requiring access to terminal
// state (no pointer traversal into the page list).
//
// It is more expensive to create than a simple selection, but more
// efficient to render since it has all information without having
// to dereference pointers into the terminal state.
pub struct FlattenedHighlight {
pub mut:
	// The chunks that make up this highlight, one per page node.
	chunks []Chunk
	// The x coordinate of the top-left of the highlight.
	top_x u16
	// The x coordinate of the bottom-right of the highlight.
	bot_x u16
}

// Create an empty FlattenedHighlight.
pub fn FlattenedHighlight.empty() FlattenedHighlight {
	return FlattenedHighlight{}
}

// Free resources held by this highlight.
pub fn (mut self FlattenedHighlight) deinit() {
	self.chunks = []
}

// Clone this highlight (deep copy of chunks).
pub fn (self &FlattenedHighlight) clone() FlattenedHighlight {
	return FlattenedHighlight{
		chunks: self.chunks.clone()
		top_x: self.top_x
		bot_x: self.bot_x
	}
}

// Initialize a flattened highlight from start and end pins by collecting
// every page chunk between them.
pub fn FlattenedHighlight.init(start terminal.PagePin, end terminal.PagePin) FlattenedHighlight {
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

// Get the start pin (top-left position) of this highlight.
pub fn (self &FlattenedHighlight) start_pin() terminal.PagePin {
	first := self.chunks[0]
	return terminal.PagePin{
		node: first.node
		y: first.start
		x: self.top_x
	}
}

// Get the end pin (bottom-right position) of this highlight.
pub fn (self &FlattenedHighlight) end_pin() terminal.PagePin {
	last := self.chunks[self.chunks.len - 1]
	return terminal.PagePin{
		node: last.node
		y: last.end - 1
		x: self.bot_x
	}
}

// Convert to an untracked highlight (just start/end pins).
pub fn (self &FlattenedHighlight) untracked() UntrackedHighlight {
	first := self.chunks[0]
	last := self.chunks[self.chunks.len - 1]
	return UntrackedHighlight{
		start: terminal.PagePin{
			node: first.node
			x: self.top_x
			y: first.start
		}
		end: terminal.PagePin{
			node: last.node
			x: self.bot_x
			y: last.end - 1
		}
	}
}

// ============================================================
// UntrackedHighlight
// ============================================================

// UntrackedHighlight holds a start and end position that are not
// tracked by the page list. If pages are modified, these positions
// may become invalid.
pub struct UntrackedHighlight {
pub mut:
	start terminal.PagePin
	end   terminal.PagePin
}

pub fn (self UntrackedHighlight) eql(other UntrackedHighlight) bool {
	return self.start.eql(other.start) && self.end.eql(other.end)
}

// Track this highlight by creating tracked pins in its backing page list.
pub fn (self &UntrackedHighlight) track(mut list terminal.PageList) TrackedHighlight {
	return TrackedHighlight.init(mut list, self.start, self.end)
}

// Initialize a tracked highlight by registering both pins with the page list.
pub fn TrackedHighlight.init(mut list terminal.PageList, start terminal.PagePin, end terminal.PagePin) TrackedHighlight {
	start_pin := list.track_pin(start)
	end_pin := list.track_pin(end)
	return TrackedHighlight{
		start: start_pin
		end: end_pin
	}
}

// Initialize from pins that are already tracked.
// Do not call deinit on highlights created with this function.
pub fn TrackedHighlight.init_assume(start &terminal.PagePin, end &terminal.PagePin) TrackedHighlight {
	return TrackedHighlight{
		start: start
		end: end
	}
}

// ============================================================
// TrackedHighlight
// ============================================================

// TrackedHighlight holds tracked pins that are automatically updated
// when the page list is modified. The pins are owned by the page list
// and must be untracked (deinit) when no longer needed.
pub struct TrackedHighlight {
pub mut:
	// Tracked start pin. Auto-updates on page modifications.
	start &terminal.PagePin = unsafe { nil }
	// Tracked end pin. Auto-updates on page modifications.
	end &terminal.PagePin = unsafe { nil }
}

// Free tracked resources by untracking the pins.
pub fn (self TrackedHighlight) deinit(mut list terminal.PageList) {
	list.untrack_pin(self.start)
	list.untrack_pin(self.end)
}
