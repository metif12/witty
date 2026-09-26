module osc

fn test_osc22_pointer_cursor() {
	mut p := Parser.init(unsafe { nil })
	input := '22;pointer'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd is MouseShape
	assert (cmd as MouseShape).value == 'pointer'
}
