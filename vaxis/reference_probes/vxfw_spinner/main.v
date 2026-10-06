module main

import os
import time
import vaxis
import vaxis.vxfw

fn style(index int) vaxis.Style {
	return match index {
		0 {
			vaxis.Style{}
		}
		1 {
			vaxis.Style{
				fg:     vaxis.ColorIndex{
					index: 17
				}
				bg:     vaxis.ColorIndex{
					index: 231
				}
				bold:   true
				italic: true
			}
		}
		else {
			vaxis.Style{
				fg:            vaxis.ColorRgb{
					rgb: [u8(1), 128, 255]!
				}
				bg:            vaxis.ColorRgb{
					rgb: [u8(99), 33, 2]!
				}
				ul:            vaxis.ColorIndex{
					index: 88
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
		}
	}
}

fn initial(p []string) vxfw.Spinner {
	mut value := vxfw.Spinner{
		frame: u8(p[2].int())
		style: style(p[4].int())
	}
	value.count.store(u16(p[1].int()))
	value.was_spinning.store(p[3].int() != 0)
	return value
}

fn state(mut spinner vxfw.Spinner, ctx vxfw.EventContext) string {
	return '${spinner.count.load()},${spinner.frame},${int(spinner.was_spinning())},${int(ctx.phase)},${int(ctx.consume_event)},${int(ctx.redraw)},${int(ctx.quit)},${ctx.cmds.len}'
}

fn command(mut spinner vxfw.Spinner, cmd ?vxfw.Command, before i64, after i64) string {
	if value := cmd {
		match value {
			vxfw.Tick {
				return 'T${int(value.deadline_ms >= before + 83 && value.deadline_ms <= after + 83)},${int(value.widget.eql(spinner.widget()))},${int(value.widget.userdata == unsafe { voidptr(&spinner) })},${int(value.widget.event_handler != none)},${int(value.widget.capture_handler == none)};'
			}
			vxfw.QueueRefresh {
				return 'Q;'
			}
			else {
				panic('UnexpectedCommand')
			}
		}
	}
	return '-;'
}

fn draw_context(width u16, height u16, bounded bool) vxfw.DrawContext {
	return vxfw.DrawContext{
		min:       vxfw.Size{
			width:  width
			height: height
		}
		max:       if bounded {
			vxfw.MaxSize{
				width:  u16(0)
				height: u16(0)
			}
		} else {
			vxfw.MaxSize{}
		}
		cell_size: vxfw.Size{
			width:  10
			height: 20
		}
	}
}

fn plain(cell vaxis.Cell, expected vaxis.Style) bool {
	return cell.char_.width == 1 && cell.style.eql(expected) && !cell.default_ && !cell.wrapped
		&& cell.link.uri.len == 0 && cell.link.params.len == 0 && cell.image == none
		&& cell.scale.eql(vaxis.CellScale{})
}

fn cell(value vaxis.Cell, expected vaxis.Style) string {
	return '${value.char_.grapheme.bytes().hex()}/${value.char_.width},${int(plain(value, expected))}'
}

fn surface(value vxfw.Surface, mut spinner vxfw.Spinner) string {
	mut rest_ok := true
	for entry in value.buffer[1..] {
		rest_ok = rest_ok && plain(entry, spinner.style) && entry.char_.grapheme == ' '
	}
	return '${value.size.width},${value.size.height},${value.buffer.len},${int(value.widget.eql(spinner.widget()))},${int(value.cursor == none)},${value.children.len},${int(rest_ok)}|${cell(value.buffer[0],
		spinner.style)}|${cell(value.buffer[value.buffer.len - 1], spinner.style)}'
}

fn worker(value &vxfw.Spinner, n int) int {
	mut spinner := unsafe { &vxfw.Spinner(value) }
	mut commands := 0
	for _ in 0 .. n {
		if _ := spinner.start() { commands++ }
	}
	return commands
}

fn trap(mode string) ! {
	mut spinner := vxfw.Spinner{
		frame: 15
	}
	spinner.count.store(1)
	mut ctx := vxfw.EventContext{
		cmds: []vxfw.Command{}
	}
	match mode {
		'trap_tick_direct' {
			spinner.handle_event(mut ctx, vxfw.TickEvent{})!
		}
		'trap_tick_callback' {
			spinner.widget().handle_event(mut ctx, vxfw.TickEvent{})!
		}
		'trap_draw_direct' {
			spinner.frame = 8
			_ := spinner.draw(draw_context(0, 0, false))!
		}
		'trap_draw_callback' {
			_ := spinner.widget().draw(draw_context(0, 0, false))!
		}
		'trap_area' {
			spinner.count.store(0)
			_ := spinner.draw(draw_context(256, 256, false))!
		}
		'trap_area_before_frame' {
			_ := spinner.draw(draw_context(256, 256, false))!
		}
		else {
			return error('InvalidTrap')
		}
	}

	println('UNEXPECTED returned')
}

fn main() {
	if os.args[1].starts_with('trap_') {
		trap(os.args[1]) or { eprintln('UNEXPECTED error ${err}') }
		return
	}
	data := os.read_file(os.args[1]) or { panic(err) }
	mut output := []string{}
	for line in data.split_into_lines() {
		if line.len == 0 { continue
		 }
		p := line.split('|')
		mut spinner := initial(p)
		flags := p[6].int()
		mut ctx := vxfw.EventContext{
			cmds:          [vxfw.Command(vxfw.QueueRefresh{})]
			phase:         unsafe { vxfw.Phase(p[5].int()) }
			consume_event: flags & 1 != 0
			redraw:        flags & 2 != 0
			quit:          flags & 4 != 0
		}
		mut row := '${output.len}|'
		match p[0] {
			'S' {
				for op in p[7].bytes() {
					before := time.now().unix_milli()
					match op {
						`s` {
							cmd := spinner.start()
							after := time.now().unix_milli()
							row += command(mut spinner, cmd, before, after)
						}
						`p` {
							spinner.stop()
						}
						`t`, `u`, `n`, `c` {
							previous := ctx.cmds.len
							match op {
								`t` {
									spinner.handle_event(mut ctx, vxfw.TickEvent{}) or {
										panic(err)
									}
								}
								`u` {
									spinner.widget().handle_event(mut ctx, vxfw.TickEvent{}) or {
										panic(err)
									}
								}
								`n` {
									spinner.handle_event(mut ctx, vxfw.UserEvent{ name: 'test' }) or {
										panic(err)
									}
								}
								else {
									spinner.widget().capture_event(mut ctx, vxfw.TickEvent{}) or {
										panic(err)
									}
								}
							}

							after := time.now().unix_milli()
							for cmd in ctx.cmds[previous..] {
								row += command(mut spinner, cmd, before, after)
							}
						}
						else {
							panic('InvalidOperation')
						}
					}

					row += state(mut spinner, ctx) + ';'
				}
			}
			'D' {
				dc := draw_context(u16(p[7].int()), u16(p[8].int()), p[9].int() != 0)
				value := if p[10].int() != 0 { spinner.widget().draw(dc) or { panic(err) } } else { spinner.draw(dc) or {
						panic(err)} }
				row += surface(value, mut spinner) + '|' + state(mut spinner, ctx)
			}
			'C' {
				mut copied := spinner
				_ = copied.start()
				copied.stop()
				copied.stop()
				copied.was_spinning.store(false)
				copied.handle_event(mut ctx, vxfw.TickEvent{}) or { panic(err) }
				row += state(mut spinner, ctx) + '|' + state(mut copied, ctx) +
					'|${int(spinner.widget().eql(copied.widget()))}'
			}
			'A' {
				mut threads := []thread int{}
				for _ in 0 .. 4 {
					threads << spawn worker(&spinner, p[7].int())
				}
				mut commands := 0
				for job in threads {
					commands += job.wait()
				}
				row += state(mut spinner, ctx) + '|${commands}'
			}
			else {
				panic('InvalidMode')
			}
		}

		row += '|Q${int(ctx.cmds[0] is vxfw.QueueRefresh)}'
		output << row
	}
	print(output.join('\n') + '\n')
}
