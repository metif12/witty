module main

import strings
import vaxis
import vaxis.vxfw

fn draw(_ voidptr, _ vxfw.DrawContext) !vxfw.Surface {
	return error('OutOfMemory')
}

fn widget(id usize) vxfw.Widget {
	return vxfw.Widget{
		userdata: voidptr(id)
		draw_fn:  draw
	}
}

fn focus_id(value ?vxfw.Widget) usize {
	return if w := value { usize(w.userdata) } else { usize(0) }
}

fn main() {
	mut out := strings.new_builder(1024)
	out.writeln('D|${vxfw.AppOptions{}.framerate}')
	for fps in 0 .. 256 {
		mut opts := vxfw.AppOptions{}
		opts.framerate = u8(fps)
		mut copied := opts
		copied.framerate = u8(255 - fps)
		out.writeln('O|${opts.framerate}|${copied.framerate}')
	}
	widths := [u16(0), 1, 31, 255, 65535]
	deadlines := [i64(-9223372036854775807) - 1, -1, 0, 17, 9223372036854775807]
	mut base_vx := vaxis.Vaxis.new(vaxis.VaxisOptions{})
	defer { base_vx.deinit() }
	for width in widths {
		for flags in 0 .. 32 {
			for clipboard in 0 .. 2 {
				for count in 0 .. 4 {
					for focus in 0 .. 4 {
						mut storage := [
							vxfw.Tick{
								deadline_ms: deadlines[0]
								widget:      widget(1)
							},
							vxfw.Tick{
								deadline_ms: deadlines[3]
								widget:      widget(2)
							},
							vxfw.Tick{
								deadline_ms: deadlines[4]
								widget:      widget(3)
							},
						]
						mut app := vxfw.App{
							tty:         vaxis.Tty{}
							vx:          base_vx
							timers:      unsafe { storage[..count] }
							wants_focus: if focus == 0 {
								none
							} else {
								?vxfw.Widget(widget(usize(focus)))
							}
						}
						app.vx.screen.width = width
						app.vx.opts = vaxis.VaxisOptions{
							kitty_keyboard_flags: vaxis.KittyFlags.from_int(u8(flags))
							system_clipboard:     clipboard != 0
						}
						mut copied := app
						same_backing := app.timers.data == copied.timers.data
						if count != 0 {
							copied.timers[0].deadline_ms = deadlines[(flags + focus) % deadlines.len]
						}
						copied.timers = copied.timers[..if count == 0 { 0 } else { count - 1 }]
						copied.wants_focus = if focus == 0 { ?vxfw.Widget(widget(9)) } else { none }
						copied.vx.screen.width = width ^ u16(65535)
						copied.vx.opts = vaxis.VaxisOptions{
							...copied.vx.opts
							kitty_keyboard_flags: vaxis.KittyFlags.from_int(u8(31 - flags))
						}
						app.tty = vaxis.Tty{}
						out.writeln('A|${app.vx.screen.width}|${copied.vx.screen.width}|${app.vx.opts.kitty_keyboard_flags.int()}|${copied.vx.opts.kitty_keyboard_flags.int()}|${int(app.vx.opts.system_clipboard)}|${app.timers.len}|${copied.timers.len}|${int(same_backing)}|${if count == 0 {
							i64(0)
						} else {
							app.timers[0].deadline_ms
						}}|${focus_id(app.wants_focus)}|${focus_id(copied.wants_focus)}')
					}
				}
			}
		}
	}
	print(out.str())
}
