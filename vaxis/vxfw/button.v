module vxfw

import vaxis

pub type ClickHandler = fn (voidptr, mut EventContext) !

pub struct ButtonStyle {
pub mut:
	default_   vaxis.Style = vaxis.Style{
		reverse: true
	}
	mouse_down vaxis.Style = vaxis.Style{
		fg:      vaxis.ColorIndex{
			index: 4
		}
		reverse: true
	}
	hover      vaxis.Style = vaxis.Style{
		fg:      vaxis.ColorIndex{
			index: 3
		}
		reverse: true
	}
	focus      vaxis.Style = vaxis.Style{
		fg:      vaxis.ColorIndex{
			index: 5
		}
		reverse: true
	}
}

pub struct Button {
pub mut:
	label      string
	on_click   ClickHandler @[required]
	userdata   voidptr
	style      ButtonStyle
	mouse_down bool
	has_mouse  bool
	focused    bool
}

pub fn (button &Button) widget() Widget {
	return Widget{
		userdata:      unsafe { voidptr(button) }
		event_handler: button_event
		draw_fn:       button_draw
	}
}

fn button_event(ptr voidptr, mut ctx EventContext, event Event) ! {
	mut button := unsafe { &Button(ptr) }
	button.handle_event(mut ctx, event)!
}

fn button_draw(ptr voidptr, ctx DrawContext) !Surface {
	return unsafe { &Button(ptr) }.draw(ctx)
}

pub fn (mut button Button) handle_event(mut ctx EventContext, event Event) ! {
	match event {
		vaxis.Key {
			if event.matches(vaxis.enter, vaxis.Modifiers{})
				|| event.matches(u32(`j`), vaxis.Modifiers.from_int(4)) {
				button.do_click(mut ctx)!
			}
		}
		vaxis.Mouse {
			if button.mouse_down && event.type_ == .release {
				button.mouse_down = false
				button.do_click(mut ctx)!
				return
			}
			if event.type_ == .press && event.button == .left {
				button.mouse_down = true
				ctx.consume_and_redraw()
				return
			}
			ctx.consume_event()
		}
		MouseEnter {
			button.has_mouse = true
			ctx.set_mouse_shape(.pointer)
			ctx.consume_and_redraw()
		}
		vaxis.MouseLeave {
			button.has_mouse = false
			button.mouse_down = false
			ctx.set_mouse_shape(.default)
		}
		vaxis.FocusIn {
			button.focused = true
			ctx.redraw = true
		}
		vaxis.FocusOut {
			button.focused = false
			ctx.redraw = true
		}
		else {}
	}
}

fn (button &Button) do_click(mut ctx EventContext) ! {
	button.on_click(button.userdata, mut ctx)!
	ctx.consume_event = true
}

pub fn (button &Button) draw(ctx DrawContext) !Surface {
	style := if button.mouse_down {
		button.style.mouse_down
	} else if button.has_mouse {
		button.style.hover
	} else if button.focused {
		button.style.focus
	} else {
		button.style.default_
	}
	text := &Text{
		text:       button.label
		style:      style
		text_align: .center
	}
	center := Center{
		child: text.widget()
	}
	child := center.draw(ctx)!
	mut surface := Surface.init_with_children(button.widget(), child.size, child.children)
	for i in 0 .. surface.buffer.len {
		surface.buffer[i] = vaxis.Cell{
			style: style
		}
	}
	return surface
}
