module vxfw

import math
import sync.stdatomic
import vaxis

const spinner_frames = ['⣶', '⣧', '⣏', '⡟', '⠿', '⢻', '⣹', '⣼']
const spinner_time_lapse = u32(1000 / 12)

pub struct Spinner {
pub mut:
	style vaxis.Style
	// Store atomic values in the widget so ordinary value copies remain independent.
	count        stdatomic.AtomicVal[u16] = *stdatomic.new_atomic(u16(0))
	frame        u8
	was_spinning stdatomic.AtomicVal[bool] = *stdatomic.new_atomic(false)
}

pub fn (spinner &Spinner) widget() Widget {
	return Widget{
		userdata:      unsafe { voidptr(spinner) }
		event_handler: spinner_event
		draw_fn:       spinner_draw
	}
}

pub fn (mut spinner Spinner) start() ?Command {
	spinner.was_spinning.store(true)
	if spinner.count.add(1) == 0 { return Tick.@in(spinner_time_lapse, spinner.widget()) }
	return none
}

pub fn (mut spinner Spinner) stop() {
	spinner.count.store(sat_sub(spinner.count.load(), 1))
}

pub fn (mut spinner Spinner) was_spinning() bool {
	return spinner.was_spinning.load()
}

fn spinner_event(ptr voidptr, mut ctx EventContext, event Event) ! {
	mut spinner := unsafe { &Spinner(ptr) }
	spinner.handle_event(mut ctx, event)!
}

pub fn (mut spinner Spinner) handle_event(mut ctx EventContext, event Event) ! {
	if event is TickEvent {
		if spinner.count.load() == 0 {
			if spinner.was_spinning() {
				ctx.redraw = true
				spinner.was_spinning.store(false)
			}
			return
		}
		// The source frame is u4; keep its checked increment in production builds.
		if spinner.frame >= 15 { panic('integer overflow') }
		spinner.frame++
		if spinner.frame >= spinner_frames.len { spinner.frame = 0 }
		ctx.tick(spinner_time_lapse, spinner.widget())
	}
}

fn spinner_draw(ptr voidptr, ctx DrawContext) !Surface {
	mut spinner := unsafe { &Spinner(ptr) }
	return spinner.draw(ctx)
}

pub fn (mut spinner Spinner) draw(ctx DrawContext) !Surface {
	size := Size{
		width:  math.max(u16(1), ctx.min.width)
		height: math.max(u16(1), ctx.min.height)
	}
	mut surface := Surface.init(spinner.widget(), size)
	for i in 0 .. surface.buffer.len {
		surface.buffer[i] = vaxis.Cell{
			style: spinner.style
		}
	}
	if spinner.count.load() == 0 { return surface }
	if spinner.frame >= spinner_frames.len { panic('index out of bounds') }
	surface.write_cell(0, 0, vaxis.Cell{
		char_: vaxis.CellCharacter{
			grapheme: spinner_frames[spinner.frame]
			width:    1
		}
		style: spinner.style
	})
	return surface
}
