module main

import datastruct

// UnlabeledView exercises Ghostty's optional splitTreeLabel contract. Views
// without the debug helper fall back to their compact node handle.
pub struct UnlabeledView {}

pub fn (mut self UnlabeledView) ref() &UnlabeledView {
	return &UnlabeledView{}
}

pub fn (mut self UnlabeledView) unref() {}

pub fn (self &UnlabeledView) eql(other &UnlabeledView) bool {
	return self == other
}

fn test_view_label_is_optional() {
	mut left_view := UnlabeledView{}
	mut left := datastruct.SplitTree.new[UnlabeledView](&left_view)
	defer {
		left.free()
	}
	mut right_view := UnlabeledView{}
	mut right := datastruct.SplitTree.new[UnlabeledView](&right_view)
	defer {
		right.free()
	}
	mut split := left.split_(datastruct.handle_root, .right, 0.5, &right)
	defer {
		split.free()
	}

	assert split.format_text() == 'split (layout: horizontal, ratio: 0.50)\n  leaf: 2\n  leaf: 1\n'
	assert split.format_diagram() == '+---++---+\n| 2 || 1 |\n+---++---+\n'
}
