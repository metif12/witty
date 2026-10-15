const std = @import("std");
const D = std.fmt.float.FloatDecimal(u64);
const W = std.Io.Writer;
const a = std.heap.page_allocator;
pub const panic = std.debug.FullPanic(observe);
var observed_path: ?[]const u8 = null;
var observed_status: []const u8 = "";
var observed_buffer: []u8 = &.{};
var observed_view: ?[]const u8 = null;
var observed_config: []const u8 = "";
var observed_value: D = .{ .mantissa = 0, .exponent = 0, .sign = false };
var observed_copy: D = .{ .mantissa = 0, .exponent = 0, .sign = false };
fn number(text: []const u8) !usize {
    return std.fmt.parseInt(usize, text, 10);
}
fn hex(out: *W, bytes: []const u8) !void {
    for (bytes) |byte| try out.print("{x:0>2}", .{byte});
}
fn scalar(out: *W, value: D) !void {
    try out.print("{d},{d},{d}", .{ value.mantissa, value.exponent, @intFromBool(value.sign) });
}
fn state(out: *W) !void {
    try out.print("{s}|", .{observed_config});
    try hex(out, observed_buffer);
    try out.writeByte('|');
    if (observed_view) |view| {
        try out.print("{d}:{d}:", .{ view.len, @intFromPtr(view.ptr) - @intFromPtr(observed_buffer.ptr) });
        try hex(out, view);
    } else try out.writeByte('-');
    try out.writeByte('|');
    try scalar(out, observed_value);
    try out.writeByte(';');
    try scalar(out, observed_copy);
}
fn snapshot(out: *W, status: []const u8) !void {
    try out.print("{s}|", .{status});
    try state(out);
}
fn observe(message: []const u8, trace: ?usize) noreturn {
    if (observed_path) |path| {
        var out: W.Allocating = .init(a);
        snapshot(&out.writer, observed_status) catch @trap();
        std.fs.cwd().writeFile(.{ .sub_path = path, .data = out.written() }) catch @trap();
    }
    std.debug.defaultPanic(message, trace);
}
// Only zero/special records use this backend; any table access is a fixture failure.
const SpecialBackend = struct {
    pub const T = u64;
    pub const POW5_INV_BITCOUNT = 125;
    pub const POW5_BITCOUNT = 125;
    pub const bound1 = 21;
    pub const bound2 = 63;
    pub const adjust_q = false;
    pub fn computeInvPow5(_: u32) [2]u64 {
        @panic("unexpected special table access");
    }
    pub fn computePow5(_: u32) [2]u64 {
        @panic("unexpected special table access");
    }
    pub fn mulShift(_: u64, _: *const [2]u64, _: u32) u64 {
        @panic("unexpected special table access");
    }
};
// Reconstruct the public conversion record from full-precision scientific render.
// The private backend stays private and the original render body uses its own tables.
fn converted(comptime T: type, raw: u64) !D {
    const U = std.meta.Int(.unsigned, @bitSizeOf(T));
    const value: T = @bitCast(@as(U, @truncate(raw)));
    const fraction_bits = std.math.floatFractionalBits(T);
    const exponent_bits = std.math.floatExponentBits(T);
    const sign = (raw >> (@bitSizeOf(T) - 1)) != 0;
    const fraction = raw & ((@as(u64, 1) << fraction_bits) - 1);
    const exponent = (raw >> fraction_bits) & ((@as(u64, 1) << exponent_bits) - 1);
    if (exponent == ((@as(u64, 1) << exponent_bits) - 1) or (exponent == 0 and fraction == 0))
        return std.fmt.float.binaryToDecimal(u64, raw, fraction_bits, exponent_bits, false, &SpecialBackend);
    var scratch: [53]u8 = undefined;
    const text = try std.fmt.float.render(&scratch, value, .{});
    const index = std.mem.indexOfScalar(u8, text, 'e').?;
    var mantissa: u64 = 0;
    var digits: i32 = 0;
    for (text[@intFromBool(sign)..index]) |b| {
        if (b == '.') continue;
        mantissa = mantissa * 10 + b - '0';
        digits += 1;
    }
    return .{ .mantissa = mantissa, .exponent = (try std.fmt.parseInt(i32, text[index + 1 ..], 10)) - digits + 1, .sign = sign };
}
fn rendered(comptime T: type, buffer: []u8, raw: u64, options: std.fmt.float.Options) ![]const u8 {
    const U = std.meta.Int(.unsigned, @bitSizeOf(T));
    const value: T = @bitCast(@as(U, @truncate(raw)));
    return std.fmt.float.render(buffer, value, options);
}
fn record(out: *W, line: []const u8) !void {
    var parts = std.mem.splitScalar(u8, line, '|');
    var f: [8][]const u8 = undefined;
    for (&f) |*x| x.* = parts.next().?;
    const api = try number(f[0]);
    const cap = try number(f[1]);
    const offset = try number(f[2]);
    const extent = try number(f[3]);
    const bytes = try a.alloc(u8, cap);
    for (bytes, 0..) |*b, i| b.* = @truncate(i * 17 + 165);
    const buffer = bytes[offset..][0..extent];
    const raw: u64 = try number(f[4]);
    const tag = try number(f[5]);
    const value = try switch (tag) {
        0, 2 => converted(f32, raw),
        1, 3 => converted(f64, raw),
        else => unreachable,
    };
    const precision: ?usize = if (std.mem.eql(u8, f[6], "-")) null else try number(f[6]);
    const options: std.fmt.float.Options = .{ .mode = @enumFromInt(api), .precision = precision };
    const config = try a.dupe(u8, line);
    for (config) |*b| if (b.* == '|') {
        b.* = ',';
    };
    observed_config = config;
    observed_value = value;
    observed_copy = value;
    observed_buffer = bytes;
    observed_view = null;
    try snapshot(out, "ready");
    try out.writeByte('~');
    observed_status = "format";
    var status: []const u8 = "ok";
    const result: ?[]const u8 = (switch (tag) {
        0, 2 => rendered(f32, buffer, raw, options),
        1, 3 => rendered(f64, buffer, raw, options),
        else => unreachable,
    }) catch |err| blk: {
        status = @errorName(err);
        break :blk null;
    };
    observed_view = result;
    try snapshot(out, status);
    try out.writeByte('~');
    if (cap > 0) bytes[if (offset < cap) offset else cap - 1] ^= @intCast(try number(f[7]));
    try snapshot(out, "caller");
    try out.writeByte('~');
    observed_value.mantissa ^= try number(f[7]);
    try snapshot(out, "argument");
}
pub fn main() !void {
    const argv = try std.process.argsAlloc(a);
    var output: W.Allocating = .init(a);
    if (std.mem.eql(u8, argv[1], "--trap")) {
        observed_path = argv[2];
        try record(&output.writer, argv[3]);
        observed_path = null;
        try output.writer.writeByte('\n');
    } else {
        const contents = try std.fs.cwd().readFileAlloc(a, argv[1], 16 * 1024 * 1024);
        var lines = std.mem.tokenizeScalar(u8, contents, '\n');
        while (lines.next()) |line| {
            try record(&output.writer, line);
            try output.writer.writeByte('\n');
        }
    }
    var file = std.fs.File.stdout().writer(&.{});
    try file.interface.writeAll(output.written());
}
