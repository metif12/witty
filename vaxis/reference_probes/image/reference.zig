const std = @import("std");
const v = @import("vaxis");
const z = @import("zigimg");
const W = std.Io.Writer;
pub const std_options: std.Options = .{ .log_level = .err };
pub const panic = std.debug.FullPanic(observePanic);
var observed: ?*v.Vaxis = null;
var observed_image: ?*z.Image = null;
var observed_path: ?[]const u8 = null;
fn observePanic(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| if (observed) |vx| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var buf: [256]u8 = undefined;
            var writer = file.writer(&buf);
            writer.interface.print("{d}", .{vx.next_img_id}) catch {};
            if (observed_image) |img| writer.interface.print("|{s}|{d}", .{ @tagName(img.pixels), img.rawBytes().len }) catch {};
            writer.interface.flush() catch {};
        } else |_| {}
    };
    std.debug.defaultPanic(message, address);
}
fn n(p: []const []const u8, i: usize) !u16 {
    return std.fmt.parseInt(u16, p[i], 10);
}
fn hex(out: *W, bytes: []const u8) !void {
    for (bytes) |b| try out.print("{x:0>2}", .{b});
}
fn optional(out: *W, value: ?u16) !void {
    if (value) |x| try out.print("{d}", .{x}) else try out.writeAll("-");
}
fn options(out: *W, opts: v.Image.DrawOptions) !void {
    try out.print("{d}|", .{@intFromEnum(opts.scale)});
    if (opts.size) |s| {
        try optional(out, s.rows);
        try out.writeAll(",");
        try optional(out, s.cols);
    } else try out.writeAll("none");
    try out.writeAll("|");
    if (opts.pixel_offset) |o| try out.print("{d},{d}", .{ o.x, o.y }) else try out.writeAll("none");
    try out.writeAll("|");
    if (opts.z_index) |i| try out.print("{d}", .{i}) else try out.writeAll("none");
    try out.writeAll("|");
    if (opts.clip_region) |r| {
        try optional(out, r.x);
        try out.writeAll(",");
        try optional(out, r.y);
        try out.writeAll(",");
        try optional(out, r.width);
        try out.writeAll(",");
        try optional(out, r.height);
    } else try out.writeAll("none");
}
fn record(out: *W, p: []const []const u8, id: usize) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try out.print("{d}|", .{id});
    if (p[0][0] == 'G') {
        var cells = [_]v.Cell{.{ .char = .{ .grapheme = "before" }, .style = .{ .bold = true }, .link = .{ .uri = "u" } }};
        var screen: v.Screen = .{ .width = try n(p, 1), .height = try n(p, 2), .width_pix = try n(p, 3), .height_pix = try n(p, 4), .buf = &cells };
        const win: v.Window = .{ .x_off = 0, .y_off = 0, .parent_x_off = 0, .parent_y_off = 0, .width = try n(p, 5), .height = try n(p, 6), .screen = &screen };
        var img: v.Image = .{ .id = 7, .width = try n(p, 7), .height = try n(p, 8) };
        img.id = 99;
        const seed = try n(p, 10);
        const opts: v.Image.DrawOptions = .{ .scale = @enumFromInt(try n(p, 9)), .size = if (seed % 2 == 0) null else .{ .rows = seed, .cols = 0 }, .pixel_offset = if (seed % 3 == 0) null else .{ .x = seed, .y = 65535 - seed }, .z_index = if (seed % 3 == 0) null else -@as(i32, seed), .clip_region = if (seed % 2 == 0) null else .{ .x = seed, .height = 0 } };
        if (img.cellSize(win)) |s| try out.print("{d},{d}", .{ s.rows, s.cols }) else |err| try out.print("E{s}", .{@errorName(err)});
        try out.writeAll("|");
        if (img.draw(win, opts)) |_| try out.writeAll("OK") else |err| try out.print("E{s}", .{@errorName(err)});
        try out.writeAll("|");
        try hex(out, cells[0].char.grapheme);
        try out.print("|{d}|", .{@intFromBool(cells[0].style.bold)});
        try hex(out, cells[0].link.uri);
        try out.writeAll("|");
        if (cells[0].image) |placed| {
            try out.print("{d}|", .{placed.img_id});
            try options(out, placed.options);
        } else try out.writeAll("none");
        try out.writeAll("|original|");
        try options(out, opts);
    } else {
        var vx = try v.init(a, .{});
        vx.caps.kitty_graphics = try n(p, 1) != 0;
        vx.next_img_id = try std.fmt.parseInt(u32, p[2], 10);
        const payload = try a.alloc(u8, p[7].len / 2);
        _ = try std.fmt.hexToBytes(payload, p[7]);
        var bytes = W.Allocating.init(a);
        const format: v.Image.TransmitFormat = @enumFromInt(try n(p, 6));
        var managed: ?z.Image = null;
        const result = if (p[0][0] == 'L') vx.transmitLocalImagePath(a, &bytes.writer, payload, try n(p, 3), try n(p, 4), @enumFromInt(try n(p, 5)), format) else if (p[0][0] == 'M') m: {
            managed = try z.Image.fromRawPixels(a, try std.fmt.parseInt(usize, p[3], 10), try std.fmt.parseInt(usize, p[4], 10), payload, .rgb24);
            const r = vx.transmitImage(a, &bytes.writer, &managed.?, format);
            if (r) |_| {} else |err| try out.print("E{s}", .{@errorName(err)});
            try out.print("|{s}|{d}|", .{ @tagName(managed.?.pixels), managed.?.rawBytes().len });
            break :m r;
        } else vx.transmitPreEncodedImage(&bytes.writer, payload, try n(p, 3), try n(p, 4), format);
        if (result) |img| try out.print("OK|{d},{d},{d}", .{ img.id, img.width, img.height }) else |err| {
            if (managed == null) try out.print("E{s}", .{@errorName(err)});
        }
        try out.print("|{d}|", .{vx.next_img_id});
        try hex(out, bytes.written());
    }
    try out.writeAll("\n");
}
fn trap(name: []const u8, path: []const u8) !void {
    const a = std.heap.page_allocator;
    var vx = try v.init(a, .{});
    vx.caps.kitty_graphics = true;
    vx.next_img_id = 0xffffffff;
    observed = &vx;
    observed_path = path;
    var bytes = W.Allocating.init(a);
    if (std.mem.eql(u8, name, "path_id")) {
        _ = try vx.transmitLocalImagePath(a, &bytes.writer, "a", 1, 1, .file, .rgb);
    } else if (std.mem.eql(u8, name, "path_error_id")) {
        const payload = try a.alloc(u8, 3072);
        @memset(payload, 'a');
        _ = vx.transmitLocalImagePath(a, &bytes.writer, payload, 1, 1, .file, .png) catch @panic("UNEXPECTED path error");
    } else if (std.mem.eql(u8, name, "encoded_id")) {
        _ = try vx.transmitPreEncodedImage(&bytes.writer, "x", 1, 1, .png);
    } else {
        vx.next_img_id = 17;
        var pixels = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };
        var img = try z.Image.fromRawPixels(a, if (std.mem.eql(u8, name, "height_cast")) 1 else 65536, if (std.mem.eql(u8, name, "height_cast")) 65536 else if (std.mem.eql(u8, name, "png_header")) 0 else 1, &pixels, .rgb24);
        observed_image = &img;
        _ = try vx.transmitImage(a, &bytes.writer, &img, if (std.mem.eql(u8, name, "width_rgba_cast")) .rgba else if (std.mem.eql(u8, name, "width_png_cast") or std.mem.eql(u8, name, "png_header")) .png else .rgb);
    }
    @panic("UNEXPECTED returning trap");
}
pub fn main() !void {
    const a = std.heap.page_allocator;
    const args = try std.process.argsAlloc(a);
    if (args.len > 2 and std.mem.eql(u8, args[1], "--trap")) {
        try trap(args[2], args[3]);
        return;
    }
    const input = try std.fs.cwd().readFileAlloc(a, args[1], 128 * 1024 * 1024);
    var buf: [65536]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&buf);
    var rows = std.mem.splitScalar(u8, input, '\n');
    var id: usize = 0;
    while (rows.next()) |line| {
        if (line.len == 0) continue;
        var split = std.mem.splitScalar(u8, line, '|');
        var parts: [16][]const u8 = undefined;
        var len: usize = 0;
        while (split.next()) |p| {
            parts[len] = p;
            len += 1;
        }
        try record(&writer.interface, parts[0..len], id);
        id += 1;
    }
    try writer.interface.flush();
}
