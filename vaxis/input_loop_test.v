module vaxis

struct LoopCustomEvent {
	value u8
}

// Same subscription as pinned Loop.zig's test, including an application event.
type LoopTestEvent = Key | Winsize | FocusIn | LoopCustomEvent

type LoopNoResizeEvent = Key | LoopCustomEvent

type LoopReleaseEvent = KeyRelease | LoopCustomEvent

type LoopCustomOnlyEvent = LoopCustomEvent | u8

fn test_loop_queues_application_events_and_filters_terminal_events() {
	mut tty := Tty{}
	mut vx := Vaxis.new(VaxisOptions{})
	defer { _ = vx.deinit() }
	mut loop := Loop.new[LoopTestEvent](mut tty, mut vx)
	defer { loop.deinit() }
	mut cache := GraphemeCache.new()
	loop.post_event(LoopTestEvent(LoopCustomEvent{ value: 42 }))
	assert loop.try_post_event(LoopTestEvent(LoopCustomEvent{ value: 43 }))
	loop.handle_input(InputEvent(Key{ codepoint: u32(`x`) }), mut cache)
	loop.handle_input(InputEvent(FocusIn{}), mut cache)
	loop.handle_input(InputEvent(FocusOut{}), mut cache)
	loop.handle_input(InputEvent(Mouse{}), mut cache)
	loop.handle_input(InputEvent(KeyRelease{
		key: Key{
			codepoint: u32(`x`)
		}
	}), mut cache)
	first := loop.next_event()
	assert first is LoopCustomEvent
	if first is LoopCustomEvent {
		assert first.value == 42
	}
	second := loop.next_event()
	assert second is LoopCustomEvent
	if second is LoopCustomEvent {
		assert second.value == 43
	}
	loop.poll_event()
	key := loop.next_event()
	assert key is Key
	if key is Key {
		assert key.codepoint == `x`
	}
	assert loop.next_event() is FocusIn
	assert loop.try_event() == none
}

fn test_loop_direct_resize_only_posts_declared_variant() {
	mut tty := Tty{}
	mut vx := Vaxis.new(VaxisOptions{})
	defer { _ = vx.deinit() }
	mut loop := Loop.new[LoopTestEvent](mut tty, mut vx)
	defer { loop.deinit() }
	mut no_resize := Loop.new[LoopNoResizeEvent](mut tty, mut vx)
	defer { no_resize.deinit() }
	ws := Winsize{
		rows: 24
		cols: 80
	}
	post_terminal_event(mut loop, ws)
	post_terminal_event(mut no_resize, ws)
	resized := loop.next_event()
	assert resized is Winsize
	if resized is Winsize {
		assert resized == ws
	}
	assert no_resize.try_event() == none
	assert !vx.state.in_band_resize
}

fn test_loop_retains_bounded_queue_for_application_events() {
	mut tty := Tty{}
	mut vx := Vaxis.new(VaxisOptions{})
	defer { _ = vx.deinit() }
	mut loop := Loop.new[LoopNoResizeEvent](mut tty, mut vx)
	defer { loop.deinit() }
	for _ in 0 .. 512 {
		assert loop.try_post_event(LoopNoResizeEvent(LoopCustomEvent{}))
	}
	assert !loop.try_post_event(LoopNoResizeEvent(LoopCustomEvent{}))
	assert loop.next_event() is LoopCustomEvent
	assert loop.try_post_event(LoopNoResizeEvent(LoopCustomEvent{}))
}

fn test_loop_intercepts_reports_without_subscribed_terminal_events() {
	mut tty := Tty{}
	mut vx := Vaxis.new(VaxisOptions{})
	defer { _ = vx.deinit() }
	mut loop := Loop.new[LoopCustomOnlyEvent](mut tty, mut vx)
	defer { loop.deinit() }
	mut cache := GraphemeCache.new()
	vx.query_terminal_send()
	loop.handle_input(InputEvent(Key{
		codepoint: f3
		mods:      Modifiers.init(true, false, false, false, false, false, false, false)
	}), mut cache)
	assert vx.caps.explicit_width
	assert vx.screen.width_method == .unicode
	loop.handle_input(InputEvent(Key{
		codepoint: f3
		mods:      Modifiers.init(false, true, false, false, false, false, false, false)
	}), mut cache)
	assert vx.caps.scaled_text
	loop.handle_input(InputEvent(CapabilityEvent{ capability: .da1 }), mut cache)
	assert vx.queries_done.load()
	loop.handle_input(InputEvent(Winsize{ rows: 30, cols: 90 }), mut cache)
	$if windows {
		assert !vx.state.in_band_resize
	} $else {
		assert vx.state.in_band_resize
	}
	assert loop.try_event() == none
	assert cache.idx == 0
}

fn test_loop_key_text_uses_cache_only_for_subscribed_events() {
	mut tty := Tty{}
	mut vx := Vaxis.new(VaxisOptions{})
	defer { _ = vx.deinit() }
	mut loop := Loop.new[LoopNoResizeEvent](mut tty, mut vx)
	defer { loop.deinit() }
	mut releases := Loop.new[LoopReleaseEvent](mut tty, mut vx)
	defer { releases.deinit() }
	mut cache := GraphemeCache.new()
	loop.handle_input(InputEvent(Key{ codepoint: u32(`x`), text: 'abc' }), mut cache)
	key_event := loop.next_event()
	assert key_event is Key
	if key_event is Key {
		text := key_event.text or { panic('missing key text') }
		assert text == 'abc'
		assert text.str == unsafe { &cache.buf[0] }
		loop.handle_input(InputEvent(KeyRelease{
			key: Key{
				text: 'ignored'
			}
		}), mut cache)
		assert cache.idx == 3
		releases.handle_input(InputEvent(KeyRelease{
			key: Key{
				text: 'release'
			}
		}), mut cache)
		assert cache.idx == 10
		release_event := releases.next_event()
		assert release_event is KeyRelease
		if release_event is KeyRelease {
			release_text := release_event.key.text or { panic('missing release text') }
			assert release_text == 'release'
			assert release_text.str == unsafe { &cache.buf[3] }
		}
		cache.put([]u8{len: 8182, init: `y`})
		loop.handle_input(InputEvent(Key{ text: 'z' }), mut cache)
		assert cache.idx == 1
		assert text == 'zbc'
	}
	assert releases.try_event() == none
}
