const std = @import("std");
const a = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var parser: std.fmt.Parser = undefined;
var args_state: std.fmt.ArgState = undefined;
var carrier: []u8 = undefined;
var observed_path: ?[]const u8 = null;
var result_kind: []const u8 = "-";
var result_value: ?usize = null;
var result_span: []const u8 = undefined;
var step: isize = -1;
fn number(text: []const u8) usize {
    return std.fmt.parseInt(usize, text, 10) catch unreachable;
}
fn hex(out: *W, bytes: []const u8) !void {
    for (bytes) |byte| try out.print("{x:0>2}", .{byte});
}
fn state(out: *W) !void {
    try out.print("{d}|{d}:{d}:{d}:{d}|", .{ step, parser.i, args_state.next_arg, args_state.used_args, args_state.args_len });
    try hex(out, carrier);
    try out.print("|{s}", .{result_kind});
    if (std.mem.eql(u8, result_kind, "u") or std.mem.eql(u8, result_kind, "named")) {
        try out.print(":{d}:{d}:", .{ @intFromPtr(result_span.ptr) - @intFromPtr(carrier.ptr), result_span.len });
        try hex(out, result_span);
    } else if (!std.mem.eql(u8, result_kind, "-") and !std.mem.eql(u8, result_kind, "none")) {
        try out.writeByte(':');
        if (result_value) |n| {
            try out.print("{d}", .{n});
        } else {
            try out.writeByte('-');
        }
    }
}
fn observe(message: []const u8, trace: ?usize) noreturn {
    if (observed_path) |path| {
        var out: W.Allocating = .init(a);
        state(&out.writer) catch @trap();
        std.fs.cwd().writeFile(.{ .sub_path = path, .data = out.written() }) catch @trap();
    }
    std.debug.defaultPanic(message, trace);
}
fn run(out: *W, line: []const u8) !void {
    var it = std.mem.splitScalar(u8, line, '|');
    var f: [6][]const u8 = undefined;
    for (&f) |*x| x.* = it.next().?;
    carrier = try a.alloc(u8, f[0].len / 2);
    _ = try std.fmt.hexToBytes(carrier, f[0]);
    parser = .{ .bytes = carrier, .i = number(f[1]) };
    args_state = .{ .next_arg = number(f[2]), .used_args = @intCast(number(f[3])), .args_len = number(f[4]) };
    result_kind = "-";
    result_value = null;
    result_span = carrier[0..0];
    step = -1;
    try state(out);
    var actions = std.mem.splitScalar(u8, f[5], ',');
    var index: isize = 0;
    while (actions.next()) |action| : (index += 1) {
        step = index;
        var fields = std.mem.splitScalar(u8, action, ':');
        const op = fields.next().?;
        const arg = fields.next();
        var status: []const u8 = "ok";
        switch (op[0]) {
            'p' => {
                const n = parser.peek(number(arg.?));
                result_kind = "c";
                result_value = if (n) |v| v else null;
            },
            'c' => {
                const n = parser.char();
                result_kind = "c";
                result_value = if (n) |v| v else null;
            },
            'm' => {
                result_value = @intFromBool(parser.maybe(@intCast(number(arg.?))));
                result_kind = "b";
            },
            'n' => {
                result_value = parser.number();
                result_kind = "n";
            },
            'u' => {
                result_span = parser.until(@intCast(number(arg.?)));
                result_kind = "u";
            },
            's' => {
                const spec = parser.specifier() catch |err| blk: {
                    status = @errorName(err);
                    break :blk std.fmt.Specifier{ .none = {} };
                };
                if (std.mem.eql(u8, status, "ok")) switch (spec) {
                    .none => {
                        result_kind = "none";
                    },
                    .number => |n| {
                        result_kind = "number";
                        result_value = n;
                    },
                    .named => |s| {
                        result_kind = "named";
                        result_span = s;
                    },
                };
            },
            'a' => {
                result_value = args_state.nextArg(if (std.mem.eql(u8, arg.?, "-")) null else number(arg.?));
                result_kind = "a";
            },
            'h' => {
                result_kind = "h";
                result_value = @intFromBool(args_state.hasUnusedArgs());
            },
            'x' => {
                carrier[number(arg.?)] ^= @intCast(number(fields.next().?));
            },
            'w' => {
                @constCast(result_span)[number(arg.?)] ^= @intCast(number(fields.next().?));
            },
            else => unreachable,
        }
        try out.print("~{s}|", .{status});
        try state(out);
    }
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    var out: W.Allocating = .init(a);
    if (std.mem.eql(u8, args[1], "--trap")) {
        observed_path = args[2];
        try run(&out.writer, args[3]);
        observed_path = null;
        try out.writer.writeByte('\n');
    } else {
        const data = try std.fs.cwd().readFileAlloc(a, args[1], 10485760);
        var it = std.mem.tokenizeScalar(u8, data, '\n');
        while (it.next()) |line| {
            try run(&out.writer, line);
            try out.writer.writeByte('\n');
        }
    }
    var stdout = std.fs.File.stdout().writer(&.{});
    try stdout.interface.writeAll(out.written());
}
