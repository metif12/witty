const std = @import("std");
const vaxis = @import("vaxis");
const Table = vaxis.widgets.Table;
const Writer = std.Io.Writer;
const allocator = std.heap.page_allocator;
const Tag = enum { alpha, beta };
const TagAlias = Tag;
const BytesAlias = []u8;
const Types = struct { bytes: BytesAlias, optional_bytes: ?BytesAlias, text: []const u8, optional_text: ?[]const u8, kind: TagAlias, optional_kind: ?TagAlias };
const FloatAlias = f32; const DoubleAlias = f64; const IntegerAlias = i64; const UnsignedAlias = u64; const FlagAlias = bool; const TextAlias = []const u8;
const Numeric = struct { single: FloatAlias, double: DoubleAlias, optional_single: ?FloatAlias, optional_double: ?DoubleAlias, integer: IntegerAlias, natural: UnsignedAlias, flag: FlagAlias, text: TextAlias };
const Item = struct { label: []const u8, value: ?i32, enabled: bool, kind: Tag, ratio: f32, optional_tag: ?Tag };
const Single = struct { text: []const u8 };
const CallbackState = struct { calls: usize = 0, mode: u16 = 0, context: ?*Table.TableContext = null, data: ?*std.MultiArrayList(Item) = null };
fn callback(win: *vaxis.Window, pointer: *const anyopaque) !u16 {
    const state: *CallbackState = @ptrCast(@alignCast(@constCast(pointer)));
    state.calls += 1;
    if (state.mode == 3) state.context.?.start = 65535;
    if (state.mode == 4) state.data.?.items(.label)[1] = "changed";
    win.height = 2;
    win.writeCell(0, 1, .{ .char = .{ .grapheme = "X" } });
    if (state.mode == 2) return error.TableCallbackFailure;
    return 1;
}
fn number(p: []const []const u8, i: usize) !u16 { return std.fmt.parseInt(u16, p[i], 10); }
fn color(value: vaxis.Color) u32 {
    return switch (value) { .default => 0, .index => |i| 0x1000000 | @as(u32, i), .rgb => |v| 0x2000000 | (@as(u32, v[0]) << 16) | (@as(u32, v[1]) << 8) | v[2] };
}
fn output(writer: *Writer, ctx: Table.TableContext, screen: vaxis.Screen, calls: usize, err: []const u8) !void {
    try writer.print("{s}|{d},{d},{d},{d},{d};", .{ err, ctx.row, ctx.col, ctx.start, ctx.active_y_off, calls });
    for (screen.buf) |c| try writer.print("{s}/{d}/{d}/{d}/{d}/{d}/{d}/{d}/{d};", .{c.char.grapheme, c.char.width, color(c.style.fg), color(c.style.bg), color(c.style.ul), @intFromEnum(c.style.ul_style), @intFromBool(c.style.bold), @intFromBool(c.default), @intFromBool(c.wrapped)});
}
fn widthStyle(kind: u16, arg: u16, count: usize) !Table.WidthStyle {
    return switch (kind) { 0 => .dynamic_fill, 1 => .{ .dynamic_header_len = arg }, 2 => .{ .static_all = arg }, else => blk: {
        const widths = try allocator.alloc(u16, count);
        for (widths, 0..) |*w, i| w.* = @truncate(i * 3 + 1);
        break :blk .{ .static_individual = widths };
    }};
}
fn window(screen: *vaxis.Screen, width: u16, height: u16) vaxis.Window { return .{ .screen = screen, .width = width, .height = height, .x_off = 0, .y_off = 0, .parent_x_off = 0, .parent_y_off = 0 }; }
fn unexpected(message: []const u8) void { std.debug.print("{s}: {s}\n", .{"UN" ++ "EXPECTED", message}); }
fn trap(mode: []const u8) !void {
    var screen = try vaxis.Screen.init(allocator, .{ .cols = 4, .rows = 3, .x_pixel = 0, .y_pixel = 0 });
    const win = window(&screen, 4, 3);
    var state=CallbackState{.mode=3}; var selected=[_]u16{0};
    var ctx = Table.TableContext{ .selected_bg = .default, .active_bg = .default };
    if (std.mem.eql(u8, mode, "width_zero")) { _ = try Table.calcColWidth(0, &.{"x"}, .dynamic_fill, window(&screen, 0, 0)); }
    else if (std.mem.eql(u8, mode, "heads_zero")) { _ = try Table.calcColWidth(0, &.{}, .dynamic_fill, win); }
    else if (std.mem.eql(u8, mode, "heads_cast")) { const heads = try allocator.alloc([]const u8, 65536); @memset(heads, ""); _ = try Table.calcColWidth(0, heads, .dynamic_fill, win); }
    else if (std.mem.eql(u8, mode, "header_cast")) { const text = try allocator.alloc(u8, 65536); @memset(text, 'x'); _ = try Table.calcColWidth(0, &.{text}, .{ .dynamic_header_len = 0 }, win); }
    else if (std.mem.eql(u8, mode, "padding")) { _ = try Table.calcColWidth(0, &.{"x"}, .{ .dynamic_header_len = 32768 }, win); }
    else if (std.mem.eql(u8, mode, "header_add")) { _ = try Table.calcColWidth(0, &.{"xx"}, .{ .dynamic_header_len = 32767 }, win); }
    else if (std.mem.eql(u8, mode, "width_list")) { _ = try Table.calcColWidth(0, &.{"x"}, .{ .static_individual = &.{} }, win); }
    else {
        var data = std.MultiArrayList(Single){}; try data.append(allocator, .{ .text = "a" });
        if (std.mem.eql(u8, mode, "empty_headers")) ctx.header_names = .{ .custom = &.{} }
        else if (std.mem.eql(u8, mode, "empty_rows")) { data.len = 0; ctx.row = 1; }
        else if (std.mem.eql(u8, mode, "start_add")) ctx.start = 65535
        else if (std.mem.eql(u8, mode, "active_add")) { ctx.row = 1; ctx.active_y_off = 65535; ctx.active_content_fn = callback; }
        else if (std.mem.eql(u8, mode, "col_add")) { var data2 = std.MultiArrayList(Item){}; try data2.append(allocator, .{ .label = "a", .value = null, .enabled = false, .kind = .alpha, .ratio = 0, .optional_tag = null }); ctx.col_width = .{ .static_all = 32768 }; Table.drawTable(allocator, win, data2, &ctx) catch |err| { unexpected(@errorName(err)); return; }; unexpected("returned"); return; }
        else if (std.mem.eql(u8, mode, "selected_cast")) { try data.append(allocator,.{.text="b"}); try data.append(allocator,.{.text="c"}); state.context=&ctx; ctx.active_ctx=&state; ctx.active_content_fn=callback; ctx.sel_rows=&selected; }
        else if (std.mem.eql(u8, mode, "align_list")) ctx.col_align = .{ .by_idx = &.{} }
        else return error.UnknownTrap;
        Table.drawTable(allocator, win, data, &ctx) catch |err| { unexpected(@errorName(err)); return; };
    }
    unexpected("returned");
}
pub fn main() !void {
    const args = try std.process.argsAlloc(allocator);
    const text = std.fs.cwd().readFileAlloc(allocator, args[1], 64 * 1024 * 1024) catch { trap(args[1]) catch |err| { unexpected(@errorName(err)); }; return; };
    var buffer: [4096]u8 = undefined; var stdout = std.fs.File.stdout().writer(&buffer); const writer = &stdout.interface;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var p = std.ArrayList([]const u8){}; var pieces = std.mem.splitScalar(u8, line, '|'); while (pieces.next()) |part| try p.append(allocator, part);
        const parts = p.items;
        var ctx = Table.TableContext{ .selected_bg = .default, .active_bg = .default };
        if (parts[0][0] == 'C') {
            try writer.print("{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}\n", .{ctx.row, ctx.col, ctx.start, @intFromBool(ctx.active), @intFromBool(ctx.sel_rows != null), @intFromBool(ctx.active_content_fn != null), @intFromBool(@intFromPtr(ctx.active_ctx) != 0), ctx.active_y_off, ctx.y_off, ctx.cell_x_off, @intFromEnum(ctx.header_align), @intFromBool(ctx.header_borders), @intFromBool(ctx.col_borders), color(ctx.selected_fg), color(ctx.active_fg), color(ctx.hdr_bg_1), color(ctx.hdr_bg_2), color(ctx.row_bg_1), color(ctx.row_bg_2)}); continue;
        }
        if (parts[0][0] == 'N') {
            const i=try number(parts,1);
            const singles=[_]u32{0,0x80000000,0x7f800000,0xff800000,0x7fc00000,1,0x3eaaaaab,0x7f7fffff,0xff7fffff,0xbdcccccd,0x00800000};
            const doubles=[_]u64{0,0x8000000000000000,0x7ff0000000000000,0xfff0000000000000,0x7ff8000000000000,1,0x3fd5555555555555,0x7fefffffffffffff,0xffefffffffffffff,0xbfb999999999999a,0x0010000000000000};
            const single:FloatAlias=@bitCast(singles[i]); const double:DoubleAlias=@bitCast(doubles[i]);
            const item:Numeric=.{.single=single,.double=double,.optional_single=single,.optional_double=double,.integer=if(i==1) std.math.minInt(i64) else @as(i64,100000)+i,.natural=@as(u64,std.math.maxInt(u64))-i,.flag=i%2!=0,.text="alias"};
            var screen=try vaxis.Screen.init(allocator,.{.cols=3072,.rows=2,.x_pixel=0,.y_pixel=0}); defer screen.deinit(allocator); ctx.col_width=.{.static_all=384}; ctx.header_align=.left; ctx.cell_x_off=0;
            var err_text:[]const u8="ok"; var data=std.MultiArrayList(Numeric){}; try data.append(allocator,item); Table.drawTable(allocator,window(&screen,3072,2),data,&ctx) catch |err| {err_text=@errorName(err);};
            try output(writer,ctx,screen,0,err_text); try writer.writeByte('\n'); continue;
        }
        if (parts[0][0] == 'W') {
            const count = try number(parts, 3); const heads = try allocator.alloc([]const u8, count); const heading = try allocator.alloc(u8, try number(parts, 6)); @memset(heading, 'h'); @memset(heads, heading);
            const result = Table.calcColWidth(try number(parts, 4), heads, try widthStyle(try number(parts, 1), try number(parts, 5), count), window(undefined, try number(parts, 2), 0)) catch |err| { try writer.print("E:{s}\n", .{@errorName(err)}); continue; }; try writer.print("{d}\n", .{result}); continue;
        }
        const w: u16 = if (parts[0][0] == 'D') (if (try number(parts, 1) >= 4) 144 else 8) else try number(parts, 1); const h: u16 = if (parts[0][0] == 'D') 4 else try number(parts, 2);
        var screen = try vaxis.Screen.init(allocator, .{ .cols = w, .rows = h, .x_pixel = 0, .y_pixel = 0 }); defer screen.deinit(allocator); const win = window(&screen, w, h); var err_text: []const u8 = "ok";
        if (parts[0][0] == 'D') {
            const kind = try number(parts, 1);
            if (kind == 0) Table.drawTable(allocator, win, @as(u32, 1), &ctx) catch |err| { err_text = @errorName(err); };
            if (kind == 1) { var data = std.ArrayList(Single){}; try data.append(allocator, .{ .text = "a" }); Table.drawTable(allocator, win, data, &ctx) catch |err| { err_text = @errorName(err); }; }
            if (kind == 2 or kind == 3) { const data = std.MultiArrayList(Single){}; Table.drawTable(if (kind == 3) allocator else null, win, data, &ctx) catch |err| { err_text = @errorName(err); }; }
            if (kind >= 4) {
                ctx.col_width = .{.static_all=24}; ctx.header_align=.left; ctx.cell_x_off=0;
                var bytes=[_]u8{97,98}; var empty:[0]u8=.{};
                const item: Types=if(kind==4) .{.bytes=&bytes,.optional_bytes=&empty,.text="ab",.optional_text="ab",.kind=.alpha,.optional_kind=.beta} else .{.bytes=&empty,.optional_bytes=null,.text="",.optional_text=null,.kind=.beta,.optional_kind=null};
                var data=std.MultiArrayList(Types){}; try data.append(allocator,item); Table.drawTable(allocator,win,data,&ctx) catch |err| {err_text=@errorName(err);};
            }
            try output(writer, ctx, screen, 0, err_text); try writer.writeByte('\n'); continue;
        }
        var state = CallbackState{ .mode = try number(parts, 9), .context = &ctx };
        ctx.row = try number(parts, 4); ctx.start = try number(parts, 5); ctx.col = try number(parts, 6); ctx.active = try number(parts, 7) != 0; ctx.active_y_off = try number(parts, 8); ctx.active_ctx = &state; if (state.mode > 0) ctx.active_content_fn = callback;
        ctx.selected_bg = .{ .index = 3 }; ctx.selected_fg = .{ .index = 4 }; ctx.active_bg = .{ .index = 5 }; ctx.active_fg = .{ .index = 6 };
        ctx.col_width = try widthStyle(try number(parts, 10), try number(parts, 11), 6); ctx.header_align = @enumFromInt(try number(parts, 12)); ctx.col_align = .{ .all = @enumFromInt(try number(parts, 13)) };
        var selected = [_]u16{0,2,5}; if (try number(parts, 14) != 0) ctx.sel_rows = &selected;
        if (try number(parts, 15) != 0) ctx.col_indexes = .{ .by_idx = &.{3,1} };
        if (try number(parts, 16) != 0) ctx.header_names = .{ .custom = &.{"Long heading", "N", "Enabled", "Tag", "Ratio", "Optional tag"} };
        ctx.cell_x_off = try number(parts, 17); ctx.header_borders = try number(parts, 18) & 1 != 0; ctx.col_borders = try number(parts, 18) & 2 != 0; ctx.y_off = try number(parts, 19);
        var data = std.MultiArrayList(Item){}; defer data.deinit(allocator);
        const labels = [_][]const u8{"one", "two words", "λx", "four long words"};
        for (0..try number(parts, 3)) |i| try data.append(allocator, .{ .label = labels[i % 4], .value = if (i % 2 == 0) @intCast(i * 17) else null, .enabled = i % 2 != 0, .kind = if (i % 2 == 0) .alpha else .beta, .ratio = @as(f32, @floatFromInt(i)) / 3, .optional_tag = if (i % 2 == 0) .alpha else null });
        state.data=&data;
        Table.drawTable(allocator, win, data, &ctx) catch |err| { err_text = @errorName(err); };
        try output(writer, ctx, screen, state.calls, err_text); try writer.writeByte('\n');
    }
    try writer.flush();
}
