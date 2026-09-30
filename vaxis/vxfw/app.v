module vxfw

import time
import vaxis

pub struct AppOptions {
pub:
	framerate u8 = 60
}

@[heap]
pub struct App {
pub mut:
	tty vaxis.Tty
	vx  vaxis.Vaxis
mut:
	timers      []Tick
	wants_focus ?Widget
}

pub fn App.init() !&App {
	mut app := &App{
		vx: vaxis.Vaxis.new(vaxis.VaxisOptions{
			system_clipboard:     true
			kitty_keyboard_flags: vaxis.KittyFlags.init(true, true, true, true, true)
		})
	}
	app.tty = vaxis.Tty.new()!
	return app
}

pub fn (mut app App) deinit() {
	app.timers.clear()
	app.tty.write(app.vx.deinit()) or { eprintln('vaxis restore error: ${err}') }
	app.tty.deinit()
}

pub fn (mut app App) run(widget Widget, opts AppOptions) ! {
	mut loop := vaxis.Loop.new[Event](mut app.tty, mut app.vx)
	loop.start()!
	defer { loop.deinit() }
	loop.post_event(Event(InitEvent{}))
	loop.post_event(Event(vaxis.FocusIn{}))
	app.tty.write(app.vx.enter_alt_screen())!
	app.vx.query_terminal(mut app.tty, u64(time.second))!
	app.tty.write(app.vx.set_bracketed_paste(true))!
	app.tty.write(app.vx.subscribe_to_color_scheme_updates())!
	if !app.vx.state.in_band_resize { loop.init()! }
	app.vx.caps.sgr_pixels = false
	app.tty.write(app.vx.set_mouse_mode(true))!
	DrawContext.init(app.vx.screen.width_method)
	framerate := if opts.framerate > 0 { opts.framerate } else { u8(60) }
	tick_ms := i64(1000 / framerate)
	mut mouse := MouseHandler.new(widget)
	mut focus := FocusHandler.new(widget)
	focus.path_to_focused << widget
	mut next_frame_ms := time.now().unix_milli()
	mut ctx := EventContext{
		phase:  .capturing
		redraw: false
	}
	for {
		now := time.now().unix_milli()
		if now >= next_frame_ms {
			next_frame_ms = now + tick_ms
		} else {
			time.sleep((next_frame_ms - now) * time.millisecond)
			next_frame_ms += tick_ms
		}
		app.check_timers(mut ctx)!
		app.drain_events(mut loop, mut mouse, mut focus, mut ctx)!
		if wants := app.wants_focus {
			focus.focus_widget(mut ctx, wants)!
			app.handle_commands(mut ctx.cmds)
			app.wants_focus = none
		}
		if ctx.quit { return }
		if !ctx.redraw { continue
		 }
		ctx.redraw = false
		assert ctx.cmds.len == 0
		mut surface := app.do_layout(widget)!
		mouse.update_mouse(mut app, surface, mut ctx)!
		if wants := app.wants_focus {
			focus.focus_widget(mut ctx, wants)!
			app.handle_commands(mut ctx.cmds)
			app.wants_focus = none
		}
		assert ctx.cmds.len == 0
		if ctx.redraw { surface = app.do_layout(widget)! }
		mouse.last_frame = surface
		focus.update(surface)
		app.render(surface, focus.focused_widget)!
	}
}

fn (mut app App) drain_events(mut loop vaxis.Loop[Event], mut mouse MouseHandler, mut focus FocusHandler, mut ctx EventContext) ! {
	loop.queue.lock()
	defer { loop.queue.unlock() }
	for {
		event := loop.queue.drain() or { break }
		app.handle_event(event, mut mouse, mut focus, mut ctx)!
		ctx.consume_event = false
		ctx.phase = .capturing
	}
}

fn (mut app App) handle_event(event Event, mut mouse MouseHandler, mut focus FocusHandler, mut ctx EventContext) ! {
	match event {
		vaxis.FocusOut {
			mouse.mouse_exit(mut app, mut ctx)!
			focus.handle_event(mut ctx, event)!
			app.handle_commands(mut ctx.cmds)
		}
		vaxis.Mouse {
			mouse.handle_mouse(mut app, mut ctx, event)!
		}
		vaxis.Winsize {
			app.tty.write(app.vx.resize(event))!
			ctx.redraw = true
		}
		else {
			focus.handle_event(mut ctx, event)!
			app.handle_commands(mut ctx.cmds)
		}
	}
}

fn (app &App) do_layout(widget Widget) !Surface {
	screen := app.vx.screen
	return widget.draw(DrawContext{
		max:       MaxSize{
			width:  screen.width
			height: screen.height
		}
		cell_size: Size{
			width:  screen.width_pix / screen.width
			height: screen.height_pix / screen.height
		}
	})
}

fn (mut app App) render(surface Surface, focused Widget) ! {
	win := app.vx.window()
	win.clear()
	win.hide_cursor()
	win.set_cursor_shape(.default)
	surface.render(win.child(vaxis.WindowChildOptions{
		width:  surface.size.width
		height: surface.size.height
	}), focused)
	app.tty.write(app.vx.render())!
}

fn (mut app App) add_tick(tick Tick) {
	app.timers << tick
	// Stable insertion sort, descending. Equal deadlines keep their arrival order.
	mut i := app.timers.len - 1
	for i > 0 && app.timers[i].deadline_ms > app.timers[i - 1].deadline_ms {
		app.timers[i], app.timers[i - 1] = app.timers[i - 1], app.timers[i]
		i--
	}
}

fn (mut app App) handle_commands(mut cmds []Command) {
	defer { cmds.clear() }
	for cmd in cmds {
		match cmd {
			Tick {
				app.add_tick(cmd)
			}
			SetMouseShape {
				app.vx.set_mouse_shape(cmd.shape)
			}
			RequestFocus {
				app.wants_focus = cmd.widget
			}
			CopyToClipboard {
				app.tty.write(app.vx.copy_to_system_clipboard(cmd.content)) or {
					eprintln('copy error: ${err}')
				}
			}
			SetTitle {
				app.tty.write(app.vx.set_title(cmd.title)) or {
					eprintln('set_title error: ${err}')
				}
			}
			QueueRefresh {
				app.vx.queue_refresh()
			}
			Notification {
				app.tty.write(app.vx.notify(cmd.title, cmd.body)) or {
					eprintln('notify error: ${err}')
				}
			}
			QueryColor {
				app.tty.write(app.vx.query_color(cmd.kind)) or {
					eprintln('queryColor error: ${err}')
				}
			}
		}
	}
}

fn (mut app App) check_timers(mut ctx EventContext) ! {
	now := time.now().unix_milli()
	for app.timers.len > 0 {
		tick := app.timers.pop()
		if now < tick.deadline_ms {
			app.timers << tick
			break
		}
		tick.widget.handle_event(mut ctx, Event(TickEvent{}))!
	}
	app.handle_commands(mut ctx.cmds)
}

struct MouseHandler {
mut:
	last_frame    Surface
	last_hit_list []HitResult
	mouse         ?vaxis.Mouse
}

fn MouseHandler.new(root Widget) MouseHandler {
	return MouseHandler{
		last_frame: Surface.empty(root)
	}
}

fn (mut handler MouseHandler) update_mouse(mut app App, surface Surface, mut ctx EventContext) ! {
	mouse := handler.mouse or { return }
	mut hits := mouse_hits(surface, mouse)
	handler.update_hits(mut app, mut ctx, hits)!
}

fn mouse_hits(surface Surface, mouse vaxis.Mouse) []HitResult {
	mut hits := []HitResult{}
	point := Point{
		row: mouse.row
		col: mouse.col
	}
	if (SubSurface{
		surface: surface
	}).contains_point(point)
	{
		surface.hit_test(mut hits, point)
	}
	return hits
}

fn hits_contain(hits []HitResult, widget Widget) bool {
	for item in hits {
		if item.widget.eql(widget) { return true }
	}
	return false
}

fn (mut handler MouseHandler) update_hits(mut app App, mut ctx EventContext, hits []HitResult) ! {
	for item in handler.last_hit_list {
		if !hits_contain(hits, item.widget) {
			item.widget.handle_event(mut ctx, Event(vaxis.MouseLeave{}))!
			app.handle_commands(mut ctx.cmds)
		}
	}
	for item in hits {
		if !hits_contain(handler.last_hit_list, item.widget) {
			item.widget.handle_event(mut ctx, Event(MouseEnter{}))!
			app.handle_commands(mut ctx.cmds)
		}
	}
	handler.last_hit_list = hits.clone()
}

fn (mut handler MouseHandler) handle_mouse(mut app App, mut ctx EventContext, mouse vaxis.Mouse) ! {
	handler.mouse = mouse
	mut hits := mouse_hits(handler.last_frame, mouse)
	handler.update_hits(mut app, mut ctx, hits)!
	if hits.len == 0 { return }
	target := hits.pop()
	ctx.phase = .capturing
	for item in hits {
		item.widget.capture_event(mut ctx, Event(vaxis.Mouse{
			...mouse
			col: item.local.col
			row: item.local.row
		}))!
		app.handle_commands(mut ctx.cmds)
		if ctx.consume_event { return }
	}
	ctx.phase = .at_target
	target.widget.handle_event(mut ctx, Event(vaxis.Mouse{
		...mouse
		col: target.local.col
		row: target.local.row
	}))!
	app.handle_commands(mut ctx.cmds)
	if ctx.consume_event { return }
	ctx.phase = .bubbling
	for hits.len > 0 {
		item := hits.pop()
		item.widget.handle_event(mut ctx, Event(vaxis.Mouse{
			...mouse
			col: item.local.col
			row: item.local.row
		}))!
		app.handle_commands(mut ctx.cmds)
		if ctx.consume_event { return }
	}
}

fn (mut handler MouseHandler) mouse_exit(mut app App, mut ctx EventContext) ! {
	for item in handler.last_hit_list {
		item.widget.handle_event(mut ctx, Event(vaxis.MouseLeave{}))!
		app.handle_commands(mut ctx.cmds)
	}
}

struct FocusHandler {
	root Widget
mut:
	focused_widget  Widget
	path_to_focused []Widget
}

fn FocusHandler.new(root Widget) FocusHandler {
	return FocusHandler{
		root:           root
		focused_widget: root
	}
}

fn (mut handler FocusHandler) update(surface Surface) {
	handler.path_to_focused.clear()
	handler.child_has_focus(surface)
	if !handler.root.eql(surface.widget) { handler.path_to_focused << handler.root }
	handler.path_to_focused.reverse_in_place()
}

fn (mut handler FocusHandler) child_has_focus(surface Surface) bool {
	if handler.focused_widget.eql(surface.widget) {
		handler.path_to_focused << surface.widget
		return true
	}
	for child in surface.children {
		if handler.child_has_focus(child.surface) {
			handler.path_to_focused << surface.widget
			return true
		}
	}
	return false
}

fn (mut handler FocusHandler) focus_widget(mut ctx EventContext, widget Widget) ! {
	assert widget.event_handler != none
	if handler.focused_widget.eql(widget) { return }
	ctx.phase = .at_target
	handler.focused_widget.handle_event(mut ctx, Event(vaxis.FocusOut{}))!
	handler.focused_widget = widget
	widget.handle_event(mut ctx, Event(vaxis.FocusIn{}))!
}

fn (handler &FocusHandler) handle_event(mut ctx EventContext, event Event) ! {
	path := handler.path_to_focused
	assert path.len > 0
	ctx.phase = .capturing
	for widget in path {
		widget.capture_event(mut ctx, event)!
		if ctx.consume_event { return }
	}
	ctx.phase = .at_target
	path.last().handle_event(mut ctx, event)!
	if ctx.consume_event { return }
	ctx.phase = .bubbling
	for i := path.len - 2; i >= 0; i-- {
		path[i].handle_event(mut ctx, event)!
		if ctx.consume_event { return }
	}
}
