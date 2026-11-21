module main

import os
import vaxis
import vaxis.vxfw

#include <unistd.h>

fn C.read(fd int, buf voidptr, count uint) int
fn C.fflush(stream voidptr) int

struct Probe {
mut:
	mode          string
	nodes         []Node
	ticks         u8
	draws         u16
	held_fd       int
	app           &vxfw.App          = unsafe { nil }
	event_context &vxfw.EventContext = unsafe { nil }
}

struct Node {
mut:
	id    u8
	probe &Probe = unsafe { nil }
}

fn output(value string) {
	println(value)
	C.fflush(C.stdout)
}

fn (node &Node) widget() vxfw.Widget {
	return vxfw.Widget{
		userdata:        node
		capture_handler: capture
		event_handler:   handle
		draw_fn:         draw
	}
}

fn trace(id u8, kind string, phase vxfw.Phase, event vxfw.Event) {
	match event {
		vaxis.Key {
			output('${kind}|${id}|${phase}|key|${event.codepoint}')
		}
		vaxis.Mouse {
			output('${kind}|${id}|${phase}|mouse|${event.col}|${event.row}|${event.button}|${event.type_}')
		}
		else {
			name := match event {
				vxfw.InitEvent { 'init' }
				vxfw.TickEvent { 'tick' }
				vxfw.MouseEnter { 'mouse_enter' }
				vaxis.MouseLeave { 'mouse_leave' }
				vaxis.FocusIn { 'focus_in' }
				vaxis.FocusOut { 'focus_out' }
				else { 'other' }
			}

			output('${kind}|${id}|${phase}|${name}')
		}
	}
}

fn capture(pointer voidptr, mut ctx vxfw.EventContext, event vxfw.Event) ! {
	node := unsafe { &Node(pointer) }
	trace(node.id, 'C', ctx.phase, event)
	if event is vaxis.Key {
		if node.probe.mode == 'error_capture' && event.codepoint == `e` {
			return error('ProbeFailure')
		}
		if event.codepoint == `c` && node.id == 0 { ctx.consume_event() }
	}
}

fn handle(pointer voidptr, mut ctx vxfw.EventContext, event vxfw.Event) ! {
	mut node := unsafe { &Node(pointer) }
	mut p := unsafe { node.probe }
	trace(node.id, 'H', ctx.phase, event)
	match event {
		vxfw.InitEvent {
			p.event_context = unsafe { &ctx }
			if p.mode == 'error_init' { return error('ProbeFailure') }
			if p.mode in ['init_quit', 'commands', 'buffer_probe'] { ctx.quit = true }
			if p.mode == 'buffer_probe' { p.app.tty.write('buffered-proof')! }
			if p.mode == 'seed_sorted' {
				p.app.timers << vxfw.Tick{
					deadline_ms: i64(0x7fffffffffffffff)
					widget:      node.widget()
				}
				for index in 1 .. 4 {
					p.app.timers << vxfw.Tick{
						deadline_ms: i64(3 - index)
						widget:      p.nodes[index].widget()
					}
				}
			}
			if p.mode == 'seed_resort' {
				deadlines := [i64(0), i64(2), i64(1)]
				for index, deadline in deadlines {
					p.app.timers << vxfw.Tick{
						deadline_ms: deadline
						widget:      p.nodes[index + 1].widget()
					}
				}
				ctx.add_cmd(vxfw.Command(vxfw.Tick{
					deadline_ms: i64(0x7fffffffffffffff)
					widget:      node.widget()
				}))
			}
			if p.mode == 'seed_unsorted' {
				p.app.timers << vxfw.Tick{
					deadline_ms: 0
					widget:      p.nodes[1].widget()
				}
				p.app.timers << vxfw.Tick{
					deadline_ms: i64(0x7fffffffffffffff)
					widget:      node.widget()
				}
			}
			if p.mode in ['focus', 'focus_absent'] { ctx.request_focus(p.nodes[1].widget()) }
			if p.mode == 'focus_invalid' {
				mut invalid := p.nodes[1].widget()
				invalid.event_handler = none
				ctx.request_focus(invalid)
			}
			if p.mode in ['timers', 'timer_nested', 'error_tick'] {
				for index in 1 .. 4 {
					ctx.add_cmd(vxfw.Command(vxfw.Tick{
						deadline_ms: 0
						widget:      p.nodes[index].widget()
					}))
				}
				ctx.add_cmd(vxfw.Command(vxfw.Tick{
					deadline_ms: i64(0x7fffffffffffffff)
					widget:      node.widget()
				}))
			}
			if p.mode == 'commands' {
				ctx.set_title('proof-title')
				ctx.copy_to_clipboard('proof-clip')
				ctx.send_notification('proof-note', 'proof-body')
				ctx.query_color(vaxis.ColorReportKind(vaxis.ColorReportFg{}))
				ctx.set_mouse_shape(.pointer)
				ctx.queue_refresh()
			}
		}
		vaxis.FocusIn {
			if p.mode == 'error_focus' || (p.mode == 'error_focus_in' && node.id == 1) {
				return error('ProbeFailure')
			}
			if p.mode == 'buffer_probe' {
				output('BARRIER')
				mut byte := [1]u8{}
				if C.read(p.held_fd, &byte[0], 1) != 1 { panic('UNEXPECTED barrier read') }
			}
		}
		vaxis.FocusOut {
			if p.mode == 'error_focus_out' { return error('ProbeFailure') }
		}
		vaxis.Key {
			if event.codepoint == `q` { ctx.quit = true }
			if event.codepoint == `e` && p.mode == 'error_key' { return error('ProbeFailure') }
			if event.codepoint == `t` { ctx.consume_event() }
			if event.codepoint == `f` && ctx.phase == .at_target {
				ctx.request_focus(p.nodes[1].widget())
				ctx.redraw = true
			}
			if event.codepoint == `r` && ctx.phase == .at_target { ctx.queue_refresh() }
		}
		vxfw.TickEvent {
			p.ticks++
			if p.mode == 'error_tick' { return error('ProbeFailure') }
			if p.mode == 'timer_nested' && p.ticks == 1 {
				ctx.add_cmd(vxfw.Command(vxfw.Tick{ deadline_ms: 0, widget: p.nodes[0].widget() }))
			}
			if p.ticks == if p.mode == 'timer_nested' {
				u8(4)
			} else {
				u8(3)
			} {
				ctx.quit = true
			}
		}
		vxfw.MouseEnter {
			if p.mode == 'error_enter' { return error('ProbeFailure') }
		}
		vaxis.Mouse {
			if p.mode == 'error_mouse' { return error('ProbeFailure') }
		}
		else {}
	}
}

fn draw(pointer voidptr, ctx vxfw.DrawContext) !vxfw.Surface {
	node := unsafe { &Node(pointer) }
	mut p := unsafe { node.probe }
	p.draws++
	width := ctx.max.width or { panic('UNEXPECTED unbounded width') }
	height := ctx.max.height or { panic('UNEXPECTED unbounded height') }
	output('D|${node.id}|${p.draws}|${width}|${height}|${ctx.cell_size.width}|${ctx.cell_size.height}')
	if p.mode == 'error_draw' { return error('OutOfMemory') }
	if p.mode == 'layout_commands' { p.event_context.add_cmd(vxfw.Command(vxfw.QueueRefresh{})) }
	mut surface := vxfw.Surface.init(node.widget(), vxfw.Size{ width: width, height: height })
	if p.mode == 'render_invalid' { surface.buffer = [vaxis.Cell{}] }
	if node.id == 0 && p.mode !in ['focus_absent', 'render_invalid'] {
		mut child := vxfw.Surface.init(p.nodes[1].widget(), vxfw.Size{ width: 2, height: 2 })
		child.write_cell(0, 0, vaxis.Cell{
			char_: vaxis.CellCharacter{
				grapheme: 'X'
				width:    1
			}
		})
		surface.children = [
			vxfw.SubSurface{
				origin:  vxfw.RelativePoint{
					row: 1
					col: 1
				}
				surface: child
			},
		]
	}
	return surface
}

fn main() {
	args := os.args
	mut p := &Probe{
		mode:    args[1]
		held_fd: args[3].int()
	}
	p.nodes = []Node{len: 4, init: Node{
		probe: p
	}}
	for index in 0 .. 4 {
		p.nodes[index].id = u8(index)
	}
	mut app := vxfw.App.init() or { panic('UNEXPECTED init error: ${err}') }
	p.app = app
	output('I|${app.vx.opts.kitty_keyboard_flags.int()}|${int(app.vx.opts.system_clipboard)}|${app.timers.len}|${int(app.wants_focus != none)}|${app.vx.screen.width}|${app.vx.screen.height}')
	if p.mode != 'init_only' { app.tty.write(app.vx.resize(app.tty.get_winsize() or {
			panic('UNEXPECTED winsize')})) or { panic('UNEXPECTED resize') } }
	mut result := 'ok'
	if p.mode != 'init_only' { app.run(p.nodes[0].widget(), vxfw.AppOptions{
			framerate: u8(args[2].int())
		}) or { result = err.msg() } }
	output('R|${result}|${app.timers.len}|${int(app.wants_focus != none)}|${app.vx.screen.width}|${app.vx.screen.height}|${int(app.vx.state.alt_screen)}|${int(app.vx.state.mouse)}|${int(app.vx.state.bracketed_paste)}')
	app.deinit()
	output('DONE')
	mut release := [1]u8{}
	if C.read(args[3].int(), &release[0], 1) != 1 { panic('UNEXPECTED release pipe') }
}
