module vxfw

import time
import vaxis

fn spinner_test_draw_context(width u16, height u16) DrawContext {
	return DrawContext{
		min:       Size{
			width:  width
			height: height
		}
		max:       MaxSize{
			width:  u16(0)
			height: u16(0)
		}
		cell_size: Size{
			width:  10
			height: 20
		}
	}
}

fn test_spinner_atomic_old_value_wrap_and_saturating_stop() {
	mut spinner := Spinner{}
	spinner.count.store(65535)
	assert spinner.start() == none
	assert spinner.count.load() == 0
	assert spinner.was_spinning()
	before := time.now().unix_milli()
	cmd := spinner.start() or { panic('missing first-start tick') }
	after := time.now().unix_milli()
	assert cmd is Tick
	if cmd is Tick {
		assert cmd.deadline_ms >= before + 83 && cmd.deadline_ms <= after + 83
		assert cmd.widget.eql(spinner.widget())
	}
	assert spinner.count.load() == 1
	spinner.stop()
	spinner.stop()
	assert spinner.count.load() == 0
	assert spinner.was_spinning()
}

fn test_spinner_stopped_tick_clears_remembered_state_once_and_keeps_frame() {
	mut spinner := Spinner{
		frame: 15
	}
	spinner.was_spinning.store(true)
	mut ctx := EventContext{
		cmds:          []Command{}
		phase:         .bubbling
		redraw:        false
		consume_event: true
		quit:          true
	}
	spinner.handle_event(mut ctx, TickEvent{}) or { panic(err) }
	assert ctx.redraw
	assert ctx.phase == .bubbling && ctx.consume_event && ctx.quit
	assert ctx.cmds.len == 0 && spinner.frame == 15
	assert !spinner.was_spinning()
	ctx.redraw = false
	spinner.handle_event(mut ctx, TickEvent{}) or { panic(err) }
	assert !ctx.redraw && ctx.cmds.len == 0
}

fn test_spinner_tick_cycles_and_accepts_high_source_u4_frames() {
	mut spinner := Spinner{}
	spinner.count.store(1)
	mut ctx := EventContext{
		cmds:   []Command{}
		redraw: false
	}
	for frame in 1 .. 8 {
		spinner.widget().handle_event(mut ctx, TickEvent{}) or { panic(err) }
		assert spinner.frame == u8(frame)
	}
	spinner.handle_event(mut ctx, TickEvent{}) or { panic(err) }
	assert spinner.frame == 0 && ctx.cmds.len == 8 && !ctx.redraw
	for frame in 8 .. 15 {
		spinner.frame = u8(frame)
		spinner.handle_event(mut ctx, TickEvent{}) or { panic(err) }
		assert spinner.frame == 0
	}
}

fn test_spinner_callbacks_keep_context_prefix_and_non_tick_state() {
	mut spinner := Spinner{
		frame: 7
	}
	spinner.count.store(2)
	widget := spinner.widget()
	assert widget.event_handler != none && widget.capture_handler == none
	mut ctx := EventContext{
		cmds:          [Command(QueueRefresh{})]
		phase:         .capturing
		redraw:        false
		consume_event: true
		quit:          true
	}
	widget.capture_event(mut ctx, TickEvent{}) or { panic(err) }
	spinner.handle_event(mut ctx, UserEvent{ name: 'unhandled' }) or { panic(err) }
	assert ctx.cmds.len == 1 && spinner.frame == 7
	widget.handle_event(mut ctx, TickEvent{}) or { panic(err) }
	assert spinner.frame == 0 && ctx.cmds.len == 2
	assert ctx.cmds[0] is QueueRefresh
	assert ctx.cmds[1] is Tick
	tick := ctx.cmds[1] as Tick
	assert tick.widget.eql(widget)
	assert ctx.phase == .capturing && !ctx.redraw && ctx.consume_event && ctx.quit
}

fn test_spinner_draw_styles_every_cell_and_ignores_maximum_constraint() {
	custom := vaxis.Style{
		fg:            vaxis.ColorRgb{
			rgb: [u8(1), 128, 255]!
		}
		bg:            vaxis.ColorIndex{
			index: 77
		}
		ul:            vaxis.ColorIndex{
			index: 12
		}
		ul_style:      .curly
		bold:          true
		dim:           true
		italic:        true
		blink:         true
		reverse:       true
		invisible:     true
		strikethrough: true
	}
	mut spinner := Spinner{
		style: custom
		frame: 3
	}
	spinner.count.store(1)
	spinner.was_spinning.store(true)
	surface := spinner.widget().draw(spinner_test_draw_context(3, 2)) or { panic(err) }
	assert surface.size == Size{
		width:  3
		height: 2
	}
	assert surface.children.len == 0 && surface.cursor == none
	assert surface.widget.eql(spinner.widget())
	assert surface.buffer[0].char_.grapheme == '⡟'
	for index, cell in surface.buffer {
		assert cell.style.eql(custom)
		assert cell.char_.width == 1 && !cell.default_ && !cell.wrapped
		assert cell.link.uri == '' && cell.link.params == '' && cell.image == none
		if index > 0 { assert cell.char_.grapheme == ' '
		 }
	}
	assert spinner.was_spinning() && spinner.frame == 3
	spinner.count.store(0)
	spinner.frame = 15
	stopped := spinner.draw(spinner_test_draw_context(0, 0)) or { panic(err) }
	assert stopped.size == Size{
		width:  1
		height: 1
	}
	assert stopped.buffer[0].char_.grapheme == ' '
	assert stopped.buffer[0].style.eql(custom)
	assert spinner.was_spinning() && spinner.frame == 15
}

fn test_spinner_value_copy_keeps_independent_atomic_fields() {
	mut original := Spinner{
		frame: 2
	}
	original.count.store(1)
	original.was_spinning.store(true)
	mut copied := original
	assert copied.start() == none
	copied.was_spinning.store(false)
	copied.stop()
	copied.stop()
	assert copied.count.load() == 0 && !copied.was_spinning()
	assert original.count.load() == 1 && original.was_spinning()
	assert !original.widget().eql(copied.widget())
}

fn test_spinner_default_instances_have_distinct_counters() {
	mut first := Spinner{}
	mut second := Spinner{}
	assert first.start() != none
	assert first.count.load() == 1 && second.count.load() == 0
	assert first.was_spinning() && !second.was_spinning()
	assert first.widget().eql(first.widget())
	assert !first.widget().eql(second.widget())
}

fn spinner_test_atomic_worker(value &Spinner, n int) int {
	mut spinner := unsafe { &Spinner(value) }
	mut commands := 0
	for _ in 0 .. n {
		if _ := spinner.start() { commands++ }
	}
	return commands
}

fn test_spinner_shared_atomic_starts_count_each_wrap_once() {
	mut spinner := Spinner{}
	mut jobs := []thread int{}
	for _ in 0 .. 4 {
		jobs << spawn spinner_test_atomic_worker(&spinner, 20000)
	}
	mut commands := 0
	for job in jobs {
		commands += job.wait()
	}
	assert spinner.count.load() == 14464
	assert commands == 2 && spinner.was_spinning()
}
