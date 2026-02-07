module renderer

import gg

// Renderer handles drawing the terminal surface.
pub struct Renderer {
pub mut:
	initialized bool
}

pub fn Renderer.init(opts RendererOpts) !Renderer {
	return Renderer{ initialized: true }
}

pub fn (mut r Renderer) deinit() {
	r.initialized = false
}

pub fn (mut r Renderer) draw_frame(force bool) ! {
	// stub: renders a frame
}

pub fn (r Renderer) surface_init(rt_surface voidptr) ! {
	// stub: initialize surface for rendering
}

pub fn (r Renderer) finalize_surface_init(rt_surface voidptr) ! {
	// stub: finalize surface init on main thread
}

pub fn (r Renderer) thread_enter(rt_surface voidptr) ! {
	// stub: enter rendering thread
}

pub struct RendererOpts {}

// State holds shared renderer state protected by a mutex.
pub struct State {
pub mut:
	terminal  voidptr
	preedit   ?Preedit
	mouse     MouseState
	inspector ?voidptr
}

pub struct MouseState {
pub mut:
	point ?Coordinate
	mods  gg.Modifier
}

pub struct Coordinate {
pub mut:
	x u32
	y u32
}

pub struct Preedit {
pub mut:
	codepoints []PreeditCodepoint
}

pub struct PreeditCodepoint {
pub:
	codepoint u32
	wide      bool
}

pub fn (p Preedit) width() int {
	mut w := 0
	for cp in p.codepoints {
		w += if cp.wide { 2 } else { 1 }
	}
	return w
}

// Thread manages the renderer thread and its mailbox.
pub struct Thread {
pub mut:
	wakeup  Wakeup
	mailbox Mailbox
}

pub fn Thread.init() !Thread {
	return Thread{}
}

pub fn (mut t Thread) deinit() {}

pub struct Wakeup {}

pub fn (w Wakeup) notify() ! {
	// stub: wakes up the renderer thread
}

pub struct Mailbox {}

pub fn (m Mailbox) push(msg Message, opts PushOpts) bool {
	_ = msg
	_ = opts
	return true
}

pub struct PushOpts {
pub:
	forever bool
}

pub struct Message {
pub:
	kind MessageKind
}

pub enum MessageKind {
	visible
	focus
	font_grid
	inspector
	change_config
	search_viewport_matches
	search_selected_match
}

pub fn Message.init_change_config(config voidptr) !Message {
	return Message{ kind: .change_config }
}

pub fn (m Message) deinit() {}

// Health status of the renderer.
pub enum Health {
	healthy
	unhealthy
}

// Size holds all sizing information.
pub struct Size {
pub mut:
	screen  ScreenSize
	cell    CellSize
	padding Padding
}

pub struct ScreenSize {
pub mut:
	width  u32
	height u32
}

pub fn (a ScreenSize) equals(b ScreenSize) bool {
	return a.width == b.width && a.height == b.height
}

pub struct CellSize {
pub mut:
	width  u32
	height u32
}

pub struct Padding {
pub mut:
	top    u32
	bottom u32
	left   u32
	right  u32
}

pub fn (mut s Size) grid() GridSize {
	usable_w := if s.screen.width > s.padding.left + s.padding.right {
		s.screen.width - s.padding.left - s.padding.right
	} else {
		u32(0)
	}
	usable_h := if s.screen.height > s.padding.top + s.padding.bottom {
		s.screen.height - s.padding.top - s.padding.bottom
	} else {
		u32(0)
	}
	cols := if s.cell.width > 0 { usable_w / s.cell.width } else { u32(0) }
	rows := if s.cell.height > 0 { usable_h / s.cell.height } else { u32(0) }
	return GridSize{ columns: cols, rows: rows }
}

pub struct GridSize {
pub:
	columns u32
	rows    u32
}

pub fn (s Size) terminal_width() u32 {
	g := s.grid()
	return g.columns * s.cell.width
}

pub fn (mut s Size) balance_padding(explicit Padding) {
	g := s.grid()
	total_w := g.columns * s.cell.width
	total_h := g.rows * s.cell.height
	usable_w := if s.screen.width > explicit.left + explicit.right {
		s.screen.width - explicit.left - explicit.right
	} else {
		u32(0)
	}
	usable_h := if s.screen.height > explicit.top + explicit.bottom {
		s.screen.height - explicit.top - explicit.bottom
	} else {
		u32(0)
	}
	extra_w := if usable_w > total_w { usable_w - total_w } else { u32(0) }
	extra_h := if usable_h > total_h { usable_h - total_h } else { u32(0) }
	s.padding = Padding{
		left: explicit.left + extra_w / 2
		right: explicit.right + (extra_w - extra_w / 2)
		top: explicit.top + extra_h / 2
		bottom: explicit.bottom + (extra_h - extra_h / 2)
	}
}
