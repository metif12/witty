@[has_globals]
module vxfw

import time
import vaxis

// Event variants and widget contracts from pinned vaxis/src/vxfw/vxfw.zig.
pub struct UserEvent {
pub mut:
	name string
	data voidptr
}

pub struct TickEvent {}

pub struct InitEvent {}

pub struct MouseEnter {}

pub type Event = vaxis.Key
	| vaxis.KeyRelease
	| vaxis.Mouse
	| vaxis.FocusIn
	| vaxis.FocusOut
	| vaxis.PasteStart
	| vaxis.PasteEnd
	| vaxis.Paste
	| vaxis.ColorReport
	| vaxis.ColorScheme
	| vaxis.Winsize
	| UserEvent
	| TickEvent
	| InitEvent
	| vaxis.MouseLeave
	| MouseEnter

pub struct Tick {
pub mut:
	deadline_ms i64
	widget      Widget
}

pub fn Tick.less_than(lhs Tick, rhs Tick) bool {
	return lhs.deadline_ms > rhs.deadline_ms
}

pub fn Tick.@in(ms u32, widget Widget) Command {
	return Command(Tick{
		deadline_ms: time.now().unix_milli() + i64(ms)
		widget:      widget
	})
}

pub struct SetMouseShape {
pub mut:
	shape vaxis.MouseShape
}

pub struct RequestFocus {
pub mut:
	widget Widget
}

pub struct CopyToClipboard {
pub mut:
	content string
}

pub struct SetTitle {
pub mut:
	title string
}

pub struct QueueRefresh {}

pub struct Notification {
pub mut:
	title ?string
	body  string
}

pub struct QueryColor {
pub mut:
	kind vaxis.ColorReportKind
}

pub type CommandList = []Command

pub type Command = Tick
	| SetMouseShape
	| RequestFocus
	| CopyToClipboard
	| SetTitle
	| QueueRefresh
	| Notification
	| QueryColor

pub enum Phase as u8 {
	capturing
	at_target
	bubbling
}

pub struct EventContext {
pub mut:
	phase         Phase = .at_target
	cmds          []Command
	consume_event bool
	redraw        bool = true
	quit          bool
}

pub fn (mut ctx EventContext) add_cmd(cmd Command) {
	ctx.cmds << cmd
}

pub fn (mut ctx EventContext) tick(ms u32, widget Widget) {
	ctx.add_cmd(Tick.@in(ms, widget))
}

pub fn (mut ctx EventContext) consume_and_redraw() {
	ctx.consume_event = true
	ctx.redraw = true
}

pub fn (mut ctx EventContext) consume_event() {
	ctx.consume_event = true
}

pub fn (mut ctx EventContext) set_mouse_shape(shape vaxis.MouseShape) {
	ctx.add_cmd(Command(SetMouseShape{ shape: shape }))
	ctx.redraw = true
}

pub fn (mut ctx EventContext) request_focus(widget Widget) {
	ctx.add_cmd(Command(RequestFocus{ widget: widget }))
}

pub fn (mut ctx EventContext) copy_to_clipboard(content string) {
	ctx.add_cmd(Command(CopyToClipboard{ content: content }))
}

pub fn (mut ctx EventContext) set_title(title string) {
	ctx.add_cmd(Command(SetTitle{ title: title }))
}

pub fn (mut ctx EventContext) queue_refresh() {
	ctx.add_cmd(Command(QueueRefresh{}))
	ctx.redraw = true
}

pub fn (mut ctx EventContext) send_notification(title ?string, body string) {
	ctx.add_cmd(Command(Notification{
		title: if text := title { text.clone() } else { none }
		body:  body.clone()
	}))
}

pub fn (mut ctx EventContext) query_color(kind vaxis.ColorReportKind) {
	ctx.add_cmd(Command(QueryColor{ kind: kind }))
}

pub struct Size {
pub mut:
	width  u16
	height u16
}

pub struct MaxSize {
pub mut:
	width  ?u16
	height ?u16
}

pub fn (max MaxSize) outside_height(row u16) bool {
	if height := max.height { return row >= height }
	return false
}

pub fn (max MaxSize) outside_width(col u16) bool {
	if width := max.width { return col >= width }
	return false
}

pub fn (max MaxSize) size() Size {
	return Size{
		width:  max.width or { panic('unbounded width') }
		height: max.height or { panic('unbounded height') }
	}
}

pub fn MaxSize.from_size(size Size) MaxSize {
	return MaxSize{
		width:  size.width
		height: size.height
	}
}

__global draw_width_method = vaxis.GWidthMethod.unicode

pub struct DrawContext {
pub mut:
	min       Size
	max       MaxSize
	cell_size Size
}

pub fn DrawContext.init(method vaxis.GWidthMethod) {
	draw_width_method = method
}

pub fn (ctx DrawContext) string_width(text string) usize {
	return usize(vaxis.gwidth(text, draw_width_method))
}

pub fn (ctx DrawContext) grapheme_iterator(text string) GraphemeIterator {
	return GraphemeIterator{
		text:  text
		inner: vaxis.grapheme_iterator(text)
	}
}

pub fn (ctx DrawContext) with_constraints(min Size, max MaxSize) DrawContext {
	return DrawContext{
		min:       min
		max:       max
		cell_size: ctx.cell_size
	}
}

pub struct GraphemeIterator {
	text string
mut:
	inner ?vaxis.GraphemeIterator
}

pub fn (mut iter GraphemeIterator) next() ?string {
	mut inner := iter.inner or { vaxis.grapheme_iterator(iter.text) }
	defer { iter.inner = inner }
	span := inner.next() or { return none }
	return span.bytes(iter.text)
}

pub type EventHandler = fn (voidptr, mut EventContext, Event) !

pub type DrawFn = fn (voidptr, DrawContext) !Surface

pub struct Widget {
pub mut:
	userdata        voidptr
	capture_handler ?EventHandler
	event_handler   ?EventHandler
	draw_fn         DrawFn @[required]
}

pub fn (widget Widget) capture_event(mut ctx EventContext, event Event) ! {
	if handler := widget.capture_handler { handler(widget.userdata, mut ctx, event)! }
}

pub fn (widget Widget) handle_event(mut ctx EventContext, event Event) ! {
	if handler := widget.event_handler { handler(widget.userdata, mut ctx, event)! }
}

pub fn (widget Widget) draw(ctx DrawContext) !Surface {
	return widget.draw_fn(widget.userdata, ctx)
}

pub fn (widget Widget) eql(other Widget) bool {
	return widget.userdata == other.userdata && voidptr(widget.draw_fn) == voidptr(other.draw_fn)
}

pub struct FlexItem {
pub mut:
	widget Widget
	flex   u8 = 1
}

pub fn FlexItem.init(child Widget, flex u8) FlexItem {
	return FlexItem{
		widget: child
		flex:   flex
	}
}

pub struct Point {
pub mut:
	row u16
	col u16
}

// Source signed i17 coordinates require a signed container in V.
pub struct RelativePoint {
pub mut:
	row i32
	col i32
}

pub struct HitResult {
pub mut:
	local  Point
	widget Widget
}

pub struct CursorState {
pub mut:
	row   u16
	col   u16
	shape vaxis.CursorShape = .default
}

pub struct Surface {
pub mut:
	size     Size
	widget   Widget
	cursor   ?CursorState
	buffer   []vaxis.Cell
	children []SubSurface
}

pub fn Surface.empty(widget Widget) Surface {
	return Surface{
		widget: widget
	}
}

pub fn Surface.create_buffer(size Size) []vaxis.Cell {
	return []vaxis.Cell{len: surface_u16_product(size.width, size.height), init: vaxis.Cell{
		default_: true
	}}
}

fn surface_u16_product(width u16, height u16) int {
	// Check before the signed int multiplication can overflow for large sizes.
	if u32(width) * u32(height) > 0xffff { panic('integer overflow') }
	return int(width) * int(height)
}

pub fn Surface.init(widget Widget, size Size) Surface {
	return Surface{
		size:   size
		widget: widget
		buffer: Surface.create_buffer(size)
	}
}

pub fn Surface.init_with_children(widget Widget, size Size, children []SubSurface) Surface {
	return Surface{
		size:     size
		widget:   widget
		buffer:   Surface.create_buffer(size)
		children: children
	}
}

pub fn (surface Surface) write_cell(col u16, row u16, cell vaxis.Cell) {
	if col >= surface.size.width || row >= surface.size.height { return }
	row_start := surface_u16_product(row, surface.size.width)
	if int(col) > 0xffff - row_start { panic('integer overflow') }
	index := row_start + int(col)
	if index >= surface.buffer.len { panic('Assertion failed') }
	unsafe {
		surface.buffer[index] = cell
	}
}

pub fn (surface Surface) read_cell(col usize, row usize) vaxis.Cell {
	if col >= usize(surface.size.width) || row >= usize(surface.size.height) {
		panic('Assertion failed')
	}
	index := row * usize(surface.size.width) + col
	if index >= usize(surface.buffer.len) { panic('Assertion failed') }
	return surface.buffer[int(index)]
}

pub fn (surface Surface) trim_height(height u16) Surface {
	if height > surface.size.height { panic('Assertion failed') }
	length := surface_u16_product(surface.size.width, height)
	if length > surface.buffer.len { panic('index out of bounds') }
	return Surface{
		size:     Size{
			width:  surface.size.width
			height: height
		}
		widget:   surface.widget
		buffer:   surface.buffer[..length]
		children: surface.children
	}
}

pub fn (surface Surface) hit_test(mut list []HitResult, point Point) {
	if point.col >= surface.size.width || point.row >= surface.size.height {
		panic('Assertion failed')
	}
	if surface.widget.event_handler != none || surface.widget.capture_handler != none {
		list << HitResult{
			local:  point
			widget: surface.widget
		}
	}
	for child in surface.children {
		if !child.contains_point(point) { continue
		 }
		child.surface.hit_test(mut list, Point{
			row: u16(i32(point.row) - child.origin.row)
			col: u16(i32(point.col) - child.origin.col)
		})
	}
}

pub fn (surface Surface) render(win vaxis.Window, focused Widget) {
	if surface.buffer.len > 0 {
		if surface.buffer.len != surface_u16_product(surface.size.width, surface.size.height) {
			panic('Assertion failed')
		}
		for index, cell in surface.buffer {
			win.write_cell(u16(index % int(surface.size.width)),
				u16(index / int(surface.size.width)), cell)
		}
	}
	if cursor := surface.cursor {
		if surface.widget.eql(focused) {
			win.show_cursor(cursor.col, cursor.row)
			win.set_cursor_shape(cursor.shape)
		}
	}
	// Sorting changes the retained child order, as in the source's mutable slice.
	mut children := unsafe { surface.children }
	// std.mem.sort is stable, including overlapping siblings with equal z-index.
	for index in 1 .. children.len {
		mut i := index
		for i > 0 && SubSurface.less_than(children[i], children[i - 1]) {
			children[i], children[i - 1] = children[i - 1], children[i]
			i--
		}
	}
	for child in children {
		child_win := win.child(vaxis.WindowChildOptions{
			x_off:  child.origin.col
			y_off:  child.origin.row
			width:  child.surface.size.width
			height: child.surface.size.height
		})
		child.surface.render(child_win, focused)
	}
}

pub fn (surface Surface) satisfies_constraints(min Size, max Size) bool {
	return surface.size.width < max.width && surface.size.width > min.width
		&& surface.size.height < max.height && surface.size.height > min.height
}

pub struct SubSurface {
pub mut:
	origin  RelativePoint
	surface Surface
	z_index u8
}

pub fn SubSurface.less_than(lhs SubSurface, rhs SubSurface) bool {
	return lhs.z_index < rhs.z_index
}

pub fn (sub SubSurface) contains_point(point Point) bool {
	return i32(point.col) >= sub.origin.col && i32(point.row) >= sub.origin.row
		&& i32(point.col) < surface_i17_end(sub.origin.col, sub.surface.size.width)
		&& i32(point.row) < surface_i17_end(sub.origin.row, sub.surface.size.height)
}

fn surface_i17_end(origin i32, size u16) i32 {
	limit := i64(origin) + i64(size)
	if limit < -0x10000 || limit > 0xffff { panic('integer overflow') }
	return i32(limit)
}
