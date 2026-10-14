const std = @import("std");
const io = @import("src/io.zig");
const c = @cImport({
    @cDefine("WITTY_IMAGE_CLOSE_DECLARATIONS", "1");
    @cInclude("fixture_shims.h");
});
const allocator = std.heap.page_allocator;
const W = std.Io.Writer;
pub const panic = std.debug.FullPanic(observe);
var close_state: ?[]const u8 = null;
var close_root: [:0]const u8 = undefined;
var close_kind: c_int = 0;
var close_keeper: c_int = -1;
var close_fd: c_int = -1;
var close_buffer: []const u8 = &.{};
var close_output: []const u8 = &.{};
var close_wire: W.Allocating = undefined;
var close_status: []const u8 = "ok";
var close_pos: u64 = 0;
var close_pending: []const u8 = &.{};
var close_drain: isize = -3;
fn snapshot(out: *W, drain: bool) !void {
    if (drain) {
        var bytes: [256]u8 = undefined;
        if (close_kind == 1) {
            while (true) {
                const n = c.witty_image_close_bytes(close_keeper, close_kind, &bytes, bytes.len);
                if (n <= 0) {
                    close_drain = n;
                    break;
                }
                try close_wire.writer.writeAll(bytes[0..@intCast(n)]);
            }
        } else {
            const n = c.witty_image_close_bytes(close_keeper, close_kind, &bytes, bytes.len);
            if (n < 0) return error.ObserverReadFailed;
            close_wire.clearRetainingCapacity();
            try close_wire.writer.writeAll(bytes[0..@intCast(n)]);
            close_drain = 0;
        }
    }
    try out.print("{d}:{d}:{d}:{d}:{d}:{d}|{x}|{x}|{d}:{x}|{s}|{x}", .{ c.witty_image_close_valid(close_fd), c.witty_image_close_valid(close_keeper), c.witty_image_close_refs(close_keeper), c.witty_image_close_kind(close_keeper), close_drain, c.witty_image_close_flags(close_fd), close_buffer, close_output, close_pos, close_pending, close_status, close_wire.written() });
}
fn observe(message: []const u8, address: ?usize) noreturn {
    if (close_state) |path| {
        var state = W.Allocating.init(allocator);
        snapshot(&state.writer, true) catch {};
        if (std.fs.cwd().createFile(path, .{})) |file| {
            defer file.close();
            file.writeAll(state.written()) catch {};
        } else |_| {}
    }
    _ = c.witty_image_close_cleanup(close_root, close_kind, close_keeper);
    std.debug.defaultPanic(message, address);
}
fn num(comptime T: type, s: []const u8) !T {
    return std.fmt.parseInt(T, s, 10);
}
fn record(line: []const u8, out: *W) !void {
    var f: [8][]const u8 = undefined;
    var it = std.mem.splitScalar(u8, line, '|');
    for (&f) |*field| field.* = it.next().?;
    close_kind = try num(c_int, f[0]);
    const writing = std.mem.eql(u8, f[1], "1");
    const choice = try num(u8, f[5]);
    close_keeper = c.witty_image_close_setup(close_root, close_kind);
    if (close_keeper < 0 or close_keeper >= 128) return error.CloseSetupFailed;
    defer _ = c.witty_image_close_cleanup(close_root, close_kind, close_keeper);
    const buffer = try allocator.alloc(u8, try num(usize, f[2]));
    defer allocator.free(buffer);
    @memset(buffer, 165);
    close_buffer = buffer;
    const output = try allocator.alloc(u8, try num(usize, f[3]));
    defer allocator.free(output);
    @memset(output, 182);
    close_output = output;
    const payload = try allocator.alloc(u8, output.len);
    defer allocator.free(payload);
    for (payload, 0..) |*b, i| b.* = @truncate(i * 17 + 11);
    const target = try std.fmt.allocPrint(allocator, "{s}/target", .{close_root});
    defer allocator.free(target);
    close_wire = W.Allocating.init(allocator);
    defer close_wire.deinit();
    close_drain = -3;
    var pending = W.Allocating.init(allocator);
    defer pending.deinit();
    for (0..try num(usize, f[6])) |_| {
        if (c.witty_image_close_seed(close_keeper, close_kind) != 0) return error.FifoSeedFailed;
        const file: std.fs.File = if (choice == 5) .{ .handle = -1 } else if (writing) try std.fs.cwd().createFile(target, .{}) else try std.fs.cwd().openFile(target, .{});
        const copied = file;
        close_fd = file.handle;
        close_status = "ok";
        close_pos = 0;
        pending.clearRetainingCapacity();
        close_pending = &.{};
        if (choice != 5) {
            if (writing) {
                var stream = io.WriteStream.initFile(file, buffer);
                stream.writer().writeAll(payload) catch |err| {
                    close_status = @errorName(err);
                };
                if (std.mem.eql(u8, f[4], "1")) stream.flush() catch |err| {
                    close_status = @errorName(err);
                };
                close_pos = stream.getPos();
                try pending.writer.writeAll(stream.writer().buffered());
            } else {
                var stream = io.ReadStream.initFile(file, buffer);
                if (std.mem.eql(u8, f[7], "1")) {
                    if (stream.reader().take(output.len)) |value| {
                        @memcpy(output, value);
                    } else |err| {
                        close_status = @errorName(err);
                    }
                } else {
                    stream.reader().readSliceAll(output) catch |err| {
                        close_status = @errorName(err);
                    };
                }
                close_pos = stream.getPos();
                try pending.writer.writeAll(stream.reader().buffered());
            }
            close_pending = pending.written();
        }
        try snapshot(out, false);
        try out.writeByte('~');
        switch (choice) {
            0 => file.close(),
            1 => copied.close(),
            2 => {
                file.close();
                file.close();
            },
            3 => {
                file.close();
                copied.close();
            },
            4 => {
                _ = c.witty_image_close_raw(file.handle);
                file.close();
            },
            else => file.close(),
        }
        try snapshot(out, true);
        try out.writeByte('~');
        if (copied.handle != file.handle) return error.CloseMutatedDescriptor;
    }
}
pub fn main() !void {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    var row = W.Allocating.init(allocator);
    defer row.deinit();
    var output = std.fs.File.stdout().writer(&.{});
    if (std.mem.eql(u8, args[1], "--trap")) {
        close_state = args[2];
        close_root = try std.fmt.allocPrintSentinel(allocator, "{s}.case", .{args[2]}, 0);
        defer allocator.free(close_root);
        try record(args[3], &row.writer);
        try output.interface.print("{s}\n", .{row.written()});
        return;
    }
    close_root = try std.fmt.allocPrintSentinel(allocator, "{s}.case", .{args[1]}, 0);
    defer allocator.free(close_root);
    const data = try std.fs.cwd().readFileAlloc(allocator, args[1], 1024 * 1024);
    defer allocator.free(data);
    var lines = std.mem.splitScalar(u8, data, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        row.clearRetainingCapacity();
        try record(line, &row.writer);
        try output.interface.print("{s}\n", .{row.written()});
    }
}
