module gtk

import apprt
import datastruct

fn test_goto_split_action_uses_wrapped_linear_navigation() {
	previous := goto_split_target(apprt.GotoSplit.previous)
	next := goto_split_target(apprt.GotoSplit.next)
	assert previous is datastruct.GotoPreviousWrapped
	assert next is datastruct.GotoNextWrapped
}

fn test_goto_split_action_preserves_spatial_navigation() {
	for value, expected in {
		apprt.GotoSplit.up:    datastruct.SpatialDirection.up
		apprt.GotoSplit.down:  datastruct.SpatialDirection.down
		apprt.GotoSplit.left:  datastruct.SpatialDirection.left
		apprt.GotoSplit.right: datastruct.SpatialDirection.right
	} {
		actual := goto_split_target(value)
		assert actual is datastruct.GotoSpatial
		assert actual.direction == expected
	}
}

fn test_goto_window_without_active_window_starts_at_list_head() {
	// The traversal loop adds one for next and subtracts one for previous.
	assert goto_window_start(-1, .next) + 1 == 0
	assert goto_window_start(-1, .previous) - 1 == 0
}

fn test_goto_window_with_active_window_starts_after_active_index() {
	assert goto_window_start(3, .next) == 3
	assert goto_window_start(3, .previous) == 3
}
