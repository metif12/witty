module osc

fn test_osc1_change_window_icon() {
	mut p := Parser.init(unsafe { nil })
	p.next(`1`)
	p.next(`;`)
	p.next(`a`)
	p.next(`b`)
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd is ChangeWindowIcon
	assert (cmd as ChangeWindowIcon).value == 'ab'
}
