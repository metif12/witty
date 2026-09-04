module tui

fn test_can_pretty_print_matches_platform() {
	$if ios || tvos || watchos {
		assert !can_pretty_print
	} $else {
		assert can_pretty_print
	}
}
