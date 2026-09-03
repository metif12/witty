module terminal

// Translated from ghostty/src/terminal/mouse_shape.zig

// The possible cursor shapes. Not all app runtimes support these shapes.
// The shapes are always based on the W3C supported cursor styles so we
// can have a cross platform list.
//
// Must be kept in sync with ghostty_cursor_shape_e
//
// Build cursor shape from string or none if it's unknown.
pub fn MouseShape.from_string(v string) ?MouseShape {
	// W3C names
	return match v {
		'default' { .default_ }
		'context-menu' { .context_menu }
		'help' { .help }
		'pointer' { .pointer }
		'progress' { .progress }
		'wait' { .wait }
		'cell' { .cell }
		'crosshair' { .crosshair }
		'text' { .text }
		'vertical-text' { .vertical_text }
		'alias' { .alias }
		'copy' { .copy }
		'move' { .move }
		'no-drop' { .no_drop }
		'not-allowed' { .not_allowed }
		'grab' { .grab }
		'grabbing' { .grabbing }
		'all-scroll' { .all_scroll }
		'col-resize' { .col_resize }
		'row-resize' { .row_resize }
		'n-resize' { .n_resize }
		'e-resize' { .e_resize }
		's-resize' { .s_resize }
		'w-resize' { .w_resize }
		'ne-resize' { .ne_resize }
		'nw-resize' { .nw_resize }
		'se-resize' { .se_resize }
		'sw-resize' { .sw_resize }
		'ew-resize' { .ew_resize }
		'ns-resize' { .ns_resize }
		'nesw-resize' { .nesw_resize }
		'nwse-resize' { .nwse_resize }
		'zoom-in' { .zoom_in }
		'zoom-out' { .zoom_out }
		// xterm/foot names
		'left_ptr' { .default_ }
		'question_arrow' { .help }
		'hand' { .pointer }
		'left_ptr_watch' { .progress }
		'watch' { .wait }
		'cross' { .crosshair }
		'xterm' { .text }
		'dnd-link' { .alias }
		'dnd-copy' { .copy }
		'dnd-move' { .move }
		'dnd-no-drop' { .no_drop }
		'crossed_circle' { .not_allowed }
		'hand1' { .grab }
		'right_side' { .e_resize }
		'top_side' { .n_resize }
		'top_right_corner' { .ne_resize }
		'top_left_corner' { .nw_resize }
		'bottom_side' { .s_resize }
		'bottom_right_corner' { .se_resize }
		'bottom_left_corner' { .sw_resize }
		'left_side' { .w_resize }
		'fleur' { .all_scroll }
		else { none }
	}
}
