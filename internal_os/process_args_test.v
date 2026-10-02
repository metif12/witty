module internal_os

fn test_embedded_process_args_replace_the_default_iterator_source() {
	previous := process_args_state.args
	defer { mut state := unsafe { process_args_state }; state.args = previous }
	set_process_args(['host', '--font-size=17'])
	assert process_args() == ['host', '--font-size=17']
	$if !macos && !ios {
		mut iter := iterator()
		assert iter.next()? == 'host'
		assert iter.next()? == '--font-size=17'
		assert iter.next() == none
	}
	set_process_args([])
	assert process_args().len == 0
}
