module terminal

// Tests for RenderState, translated from Ghostty's render.zig.

// ============================================================
// styled
// ============================================================

fn test_render_state_styled() {
	// XTODO: This test requires Terminal.decaln() which fills the screen
	// with 'E' characters. The full implementation needs the Terminal
	// stream processing pipeline.
	//
	// Original test:
	// var t = try Terminal.init(alloc, .{ .cols = 80, .rows = 24 });
	// defer t.deinit(alloc);
	// try t.decaln();
	// var state: RenderState = .empty;
	// defer state.deinit(alloc);
	// try state.update(alloc, &t);
}

// ============================================================
// basic text
// ============================================================

fn test_render_state_basic_text() {
	// XTODO: This test requires Terminal.vtStream() for feeding escape
	// sequences and the full RenderState.update() with MultiArrayList
	// cell storage.
	//
	// Original test:
	// var t = try Terminal.init(alloc, .{ .cols = 10, .rows = 3 });
	// defer t.deinit(alloc);
	// var s = t.vtStream();
	// defer s.deinit();
	// try s.nextSlice("ABCD");
	// var state: RenderState = .empty;
	// defer state.deinit(alloc);
	// try state.update(alloc, &t);
	// Verify 3 rows, 10 cells each, with 'A','B','C','D' in row 0
}

// ============================================================
// styled text
// ============================================================

fn test_render_state_styled_text() {
	// XTODO: This test requires Terminal.vtStream() for SGR escape sequences
	// (\x1b[1m for bold, etc.) and style lookups in RenderState.
	//
	// Original test:
	// try s.nextSlice("\x1b[1mA");   // Bold
	// try s.nextSlice("\x1b[0;3mB"); // Italic
	// try s.nextSlice("\x1b[0;4mC"); // Underline
	// Verify cell[0] has bold, cell[1] has italic, cell[2] has underline
}

// ============================================================
// grapheme
// ============================================================

fn test_render_state_grapheme() {
	// XTODO: This test requires grapheme cluster support (ZWJ sequences)
	// and the full RenderState cell duplication pipeline.
	//
	// Original test:
	// try s.nextSlice("A");
	// try s.nextSlice("👨‍"); // this has a ZWJ
	// Verify cell[1] is wide with grapheme data [0x200D]
}

// ============================================================
// cursor state in viewport
// ============================================================

fn test_render_state_cursor_in_viewport() {
	// XTODO: This test requires Terminal.vtStream() for cursor movement
	// escape sequences (\x1b[H, \x1b[2;3H) and style setting (\x1b[1m).
	//
	// Original test:
	// try s.nextSlice("A\x1b[H");
	// try state.update(alloc, &t);
	// Verify cursor at (0,0) in both active and viewport
	// Then move to (2,1) and verify
}

// ============================================================
// cursor state out of viewport
// ============================================================

fn test_render_state_cursor_out_of_viewport() {
	// XTODO: This test requires Terminal scrollViewport() and checking
	// that cursor.viewport becomes null when scrolled away.
	//
	// Original test:
	// try s.nextSlice("A\r\nB\r\nC\r\nD\r\n");
	// try t.scrollViewport(.top);
	// try state.update(alloc, &t);
	// Verify cursor.viewport == null
}

// ============================================================
// dirty state
// ============================================================

fn test_render_state_dirty() {
	// XTODO: This test requires fine-grained dirty tracking with
	// per-row dirty flags and the full update pipeline.
	//
	// Original test:
	// First update should trigger .full dirty
	// Reset dirty, second update with no changes -> .false_
	// Write "A", third update -> .partial with row[0] dirty
}

// ============================================================
// colors
// ============================================================

fn test_render_state_colors() {
	// XTODO: This test requires Terminal.vtStream() for OSC color
	// sequences (\x1b]12;#FF0000\x07 for cursor color, etc.)
	//
	// Original test:
	// try s.nextSlice("\x1b]12;#FF0000\x07");
	// Verify cursor color is (0xFF, 0, 0)
	// try s.nextSlice("\x1b]4;0;#FFFFFF\x07");
	// Verify palette[0] is (0xFF, 0xFF, 0xFF)
}

// ============================================================
// selection single line
// ============================================================

fn test_render_state_selection_single_line() {
	// XTODO: This test requires the full RenderState.update() with
	// selection containment calculation in the row iteration loop.
	//
	// Original test:
	// Select row 1, columns 0-2
	// Verify sels[0] == null, sels[1] == [0, 2], sels[2] == null
	// Clear selection, verify all sels are null
}

// ============================================================
// selection multiple lines
// ============================================================

fn test_render_state_selection_multiple_lines() {
	// XTODO: This test requires the full RenderState.update() with
	// multi-row selection containment.
	//
	// Original test:
	// Select from row 1 col 0 to row 2 col 2
	// Verify sels[1] == [0, cols-1], sels[2] == [0, 2]
}

// ============================================================
// linkCells
// ============================================================

fn test_render_state_link_cells() {
	// XTODO: This test requires Terminal.vtStream() for OSC 8 hyperlink
	// sequences and the full hyperlink tracking system.
	//
	// Original test:
	// try s.nextSlice("\x1b]8;;http://example.com\x1b\\LINK\x1b]8;;\x1b\\");
	// Query link at (0,0) -> 4 cells
	// Query at (4,0) -> 0 cells
}

// ============================================================
// string
// ============================================================

fn test_render_state_string() {
	// XTODO: This test requires the full RenderState with proper
	// UTF-8 encoding and wrapped line handling.
	//
	// Original test:
	// Write "AB" to 5x2 terminal
	// to_string() should produce "AB\x00\x00\x00\n\x00\x00\x00\x00\x00\n"
}

// ============================================================
// linkCells with scrollback spanning pages
// ============================================================

fn test_render_state_link_cells_scrollback_pages() {
	// XTODO: This test requires PageList with multiple page nodes
	// and cross-page hyperlink lookup.
}

// ============================================================
// linkCells with invalid viewport point
// ============================================================

fn test_render_state_link_cells_invalid_point() {
	// Simplified test: verify empty result for out-of-bounds points
	mut state := RenderState.empty()
	defer {
		state.deinit()
	}
	state.rows = 5
	state.cols = 10

	// Row out of bounds
	result1 := state.link_cells(Pin{ x: 0, y: 15 })
	assert result1.len == 0

	// Col out of bounds
	result2 := state.link_cells(Pin{ x: 15, y: 0 })
	assert result2.len == 0
}

// ============================================================
// dirty row resets highlights
// ============================================================

fn test_render_state_dirty_row_resets_highlights() {
	// XTODO: This test requires the full RenderState.update() pipeline
	// with highlight tracking and per-row arena management.
	//
	// Original test:
	// Add highlight to row 0, verify it exists
	// Write to row 0 to make it dirty
	// Update -> highlight should be cleared
}
