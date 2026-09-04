module tui

fn test_can_pretty_print_matches_platform() {
	$if ios {
		assert !can_pretty_print
	} $else {
		assert can_pretty_print
	}
}
