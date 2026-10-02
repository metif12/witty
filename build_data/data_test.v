module build_data

fn test_cli_detection_preserves_errors_and_non_actions() ! {
	assert detect_action(['tool', '--unknown', '+terminfo'])! == .terminfo
	for args in [['tool'], ['tool', 'terminfo'], ['tool', '+bad'], ['tool', '+fish', '+fish']] {
		if _ := detect_action(args) { assert false } else {
			assert err.msg() in ['NoAction', 'InvalidAction', 'MultipleActions']
		}
	}
}
