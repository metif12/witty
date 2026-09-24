module xev

// Tests translated from libxev src/linux/timerfd.zig (pinned 34fa508).

fn test_timerfd() ! {
	mut t := Timerfd.init(.monotonic, LinuxTfd{})!
	defer {
		t.deinit()
	}

	// Set
	t.set(LinuxTfdTimer{}, &TimerfdSpec{
		value: TimerfdTimeSpec{
			seconds: 60
		}
	}, unsafe { nil })!
	spec := t.get()!
	assert spec.value.seconds > 0

	// Disarm
	mut old := TimerfdSpec{}
	t.set(LinuxTfdTimer{}, &TimerfdSpec{
		value: TimerfdTimeSpec{
			seconds: 0
		}
	}, &old)!
	assert old.value.seconds > 0
}
