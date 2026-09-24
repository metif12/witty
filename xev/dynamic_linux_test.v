module xev

// Tests from libxev src/dynamic.zig (pinned 34fa508) for the Linux dynamic API,
// Xev(&.{ .io_uring, .epoll }).

fn test_dynamic_ref_all_decls() {
	// refAllDecls(@This()): every public declaration of the API is
	// referenced. V compiles every declaration, so this only touches them.
	assert dynamic
	assert candidates == [Backend.io_uring, .epoll]
	_ = sizeof(Loop)
	_ = sizeof(Completion)
	_ = sizeof(PollEvent)
	_ = sizeof(ReadBuffer)
	_ = sizeof(WriteBuffer)
	_ = sizeof(WriteQueue)
	_ = sizeof(WriteRequest)
	_ = sizeof(Async)
	_ = sizeof(Process)
	_ = sizeof(Timer)
	_ = backend()

	// EnumSubset keeps the integer values of the full enum; the source builds
	// the enum from them at comptime.
	for be in candidates {
		assert u8(subset(be)) == u8(be)
		assert superset(subset(be)) == be
	}
}

struct DynamicTestCompletionHolder {
	name string
	c    Completion
}

fn test_dynamic_completion_is_zero_able() {
	c := Completion{}
	_ = c

	// Not in the source: a Completion zero-initialized as a field of an
	// enclosing struct literal (see dynamic_completion_default_value).
	h := DynamicTestCompletionHolder{
		name: 'h'
	}
	assert h.c.tag == .epoll
	assert h.c.state() == .dead
}

fn test_dynamic_detect() ! {
	detect()!
	mut found := false
	for be in candidates {
		if u8(be) == u8(backend()) {
			assert be.api_available()
			found = true
			break
		}
	}
	assert found

	// Not in the source: detect picks the first available candidate.
	if candidates[0].api_available() {
		assert backend() == subset(candidates[0])
	}
}

fn test_dynamic_prefer() ! {
	assert prefer(candidates[0])
	mut found := false
	for be in candidates {
		if u8(be) == u8(backend()) {
			assert be.api_available()
			found = true
			break
		}
	}
	assert found
}

fn dynamic_test_loop_basics() ! {
	mut l := Loop.init(Options{})!
	defer {
		l.deinit()
	}
	l.run(.until_done)!
	l.stop()
	assert l.stopped()
}

fn test_dynamic_loop_basics() ! {
	detect()!
	dynamic_test_loop_basics()!
}

// The same test with epoll selected by prefer instead of detect.
fn test_dynamic_loop_basics_epoll() ! {
	assert prefer(.epoll)
	dynamic_test_loop_basics()!
}
