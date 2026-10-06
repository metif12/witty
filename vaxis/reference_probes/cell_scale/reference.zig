const std = @import("std");
const v = @import("vaxis");
const Scale = v.Cell.Scale;
const Alignment = @FieldType(Scale, "vertical_alignment");
const W = std.Io.Writer;
pub const std_options: std.Options = .{ .log_level = .err };
pub const panic = std.debug.FullPanic(observePanic);
var observed: Scale = .{};
var observed_path: ?[]const u8 = null;

fn observePanic(message: []const u8, address: ?usize) noreturn {
    if (observed_path) |path| {
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            var buffer: [128]u8 = undefined;
            var writer = file.writer(&buffer);
            snapshot(&writer.interface, observed) catch {};
            writer.interface.flush() catch {};
        } else |_| {}
    }
    std.debug.defaultPanic(message, address);
}

fn snapshot(out: *W, value: Scale) !void {
    try out.print("{d},{d},{d},{d},{d},{d}", .{ @as(u13, @bitCast(value)), value.scale, value.numerator, value.denominator, @intFromEnum(value.vertical_alignment), @intFromBool(value.eql(.{})) });
}

fn number(p: []const []const u8, i: usize) !u64 {
    return std.fmt.parseInt(u64, p[i], 10);
}

// Source packed @bitCast can carry the enum's unused bit pattern 3. The enum
// numeric factory is a different operation with a declared-tag check.
fn rawAlignment(n: u64) Alignment {
    const bits: u2 = @intCast(n);
    const raw: Scale = @bitCast(@as(u13, bits) << 11);
    return raw.vertical_alignment;
}

fn record(out: *W, p: []const []const u8, id: usize) !void {
    try out.print("{d}|", .{id});
    if (std.mem.eql(u8, p[0], "D")) {
        try snapshot(out, .{});
    } else if (std.mem.eql(u8, p[0], "A")) {
        const alignment: Alignment = @enumFromInt(@as(u2, @intCast(try number(p, 1))));
        try out.print("{d}", .{@intFromEnum(alignment)});
    } else if (std.mem.eql(u8, p[0], "C")) {
        const value: Scale = .{ .scale = @intCast(try number(p, 1)), .numerator = @intCast(try number(p, 2)), .denominator = @intCast(try number(p, 3)), .vertical_alignment = rawAlignment(try number(p, 4)) };
        try snapshot(out, value);
    } else if (std.mem.eql(u8, p[0], "R")) {
        const value: Scale = @bitCast(@as(u13, @intCast(try number(p, 1))));
        const copied = value;
        try snapshot(out, value);
        try out.print("|{d}", .{@intFromBool(value.eql(copied))});
    } else {
        var value: Scale = @bitCast(@as(u13, @intCast(try number(p, 1))));
        const original = value;
        value.scale = @intCast(try number(p, 2));
        try snapshot(out, value);
        try out.writeByte('|');
        value.numerator = @intCast(try number(p, 3));
        try snapshot(out, value);
        try out.writeByte('|');
        value.denominator = @intCast(try number(p, 4));
        try snapshot(out, value);
        try out.writeByte('|');
        value.vertical_alignment = rawAlignment(try number(p, 5));
        try snapshot(out, value);
        try out.writeByte('|');
        var cell: v.Cell = .{ .scale = value };
        const copied_cell = cell;
        cell.scale.scale = original.scale;
        cell.scale.numerator = original.numerator;
        cell.scale.denominator = original.denominator;
        cell.scale.vertical_alignment = original.vertical_alignment;
        try snapshot(out, cell.scale);
        try out.print("|{d},{d}", .{ @intFromBool(copied_cell.scale.eql(value)), @intFromBool(cell.scale.eql(original)) });
    }
    try out.writeByte('\n');
}

fn trap(name: []const u8, path: []const u8) !void {
    observed = .{ .scale = 5, .numerator = 11, .denominator = 13, .vertical_alignment = .bottom };
    observed_path = path;
    var raw: u64 = try std.fmt.parseInt(u64, name[std.mem.lastIndexOfScalar(u8, name, '_').? + 1 ..], 10);
    // The input is runtime state, so cast failures cannot become comptime errors.
    std.mem.doNotOptimizeAway(&raw);
    if (std.mem.startsWith(u8, name, "set_scale")) {
        observed.scale = @intCast(raw);
    } else if (std.mem.startsWith(u8, name, "set_numerator")) {
        observed.numerator = @intCast(raw);
    } else if (std.mem.startsWith(u8, name, "set_denominator")) {
        observed.denominator = @intCast(raw);
    } else if (std.mem.startsWith(u8, name, "set_alignment")) {
        observed.vertical_alignment = rawAlignment(raw);
    } else if (std.mem.startsWith(u8, name, "init_scale")) {
        observed = .{ .scale = @intCast(raw) };
    } else if (std.mem.startsWith(u8, name, "init_numerator")) {
        observed = .{ .numerator = @intCast(raw) };
    } else if (std.mem.startsWith(u8, name, "init_denominator")) {
        observed = .{ .denominator = @intCast(raw) };
    } else if (std.mem.startsWith(u8, name, "init_alignment")) {
        observed = .{ .vertical_alignment = rawAlignment(raw) };
    } else if (std.mem.startsWith(u8, name, "enum")) {
        observed.vertical_alignment = @enumFromInt(@as(u2, @intCast(raw)));
    } else {
        observed = @bitCast(@as(u13, @intCast(raw)));
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
    const input = try std.fs.cwd().readFileAlloc(a, args[1], 32 * 1024 * 1024);
    var buffer: [65536]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&buffer);
    var rows = std.mem.splitScalar(u8, input, '\n');
    var id: usize = 0;
    while (rows.next()) |line| {
        if (line.len == 0) continue;
        var split = std.mem.splitScalar(u8, line, '|');
        var parts: [8][]const u8 = undefined;
        var len: usize = 0;
        while (split.next()) |part| {
            parts[len] = part;
            len += 1;
        }
        try record(&writer.interface, parts[0..len], id);
        id += 1;
    }
    try writer.interface.flush();
}
