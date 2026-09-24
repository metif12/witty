module xev

// Tests from libxev src/api.zig (pinned 34fa508) for the Darwin default API.

fn test_completion_is_zero_able() {
	c := Completion{}
	_ = c
}

fn main_test_timer_set(ud voidptr, _ &Loop, _ &Completion, r ?ErrorKind) CallbackAction {
	if _ := r {
		panic('unreachable')
	}
	mut b := unsafe { &bool(ud) }
	unsafe {
		*b = true
	}
	return .disarm
}

// The forwarded declarations are the kqueue backend's (api.zig's refAllDecls).
fn test_default_api_forwards_kqueue() ! {
	assert !dynamic
	assert backend() == .kqueue
	assert available()

	mut loop := Loop.init(Options{})!
	defer {
		loop.deinit()
	}
	timer := Timer.init()!
	defer {
		timer.deinit()
	}
	mut called := false
	c := &Completion{}
	timer.run(mut loop, c, 1, &called, main_test_timer_set)
	loop.run(.until_done)!
	assert called
}
