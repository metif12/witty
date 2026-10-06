const std = @import("std");
const v = @import("vaxis");
const a = std.heap.page_allocator;
pub const std_options: std.Options = .{ .log_level = .err };
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    const count = try std.fmt.parseInt(u8, args[1], 10);
    const mutate = std.mem.eql(u8, args[2], "1");
    const original = try std.posix.tcgetattr(0);
    var buffer: [0]u8 = .{};
    var tty = try v.Tty.init(&buffer);
    const raw = try std.posix.tcgetattr(0);
    const was_raw = !raw.lflag.ICANON and !raw.lflag.ECHO and !raw.lflag.ISIG and !raw.iflag.ICRNL and !raw.iflag.IXON and !raw.oflag.OPOST;
    var writes: u8 = 0;
    var ws = try v.Tty.getWinsize(tty.fd);
    for (0..count) |i| {
        if (mutate and i > 0) {
            var changed = try std.posix.tcgetattr(0);
            changed.lflag.ECHO = !original.lflag.ECHO;
            try std.posix.tcsetattr(0, .NOW, changed);
        }
        tty.deinit();
        tty.writer().writeAll("D") catch {
            continue;
        };
        tty.writer().flush() catch {
            continue;
        };
        writes += 1;
        ws = try v.Tty.getWinsize(tty.fd);
    }
    const current = try std.posix.tcgetattr(0);
    var b: [128]u8 = undefined;
    const text = try std.fmt.bufPrint(&b, "{d}|{d}|{d}|{d}|{d}|{d}|{d}\n", .{ @intFromBool(was_raw), @intFromBool(std.meta.eql(current, original)), writes, ws.rows, ws.cols, ws.x_pixel, ws.y_pixel });
    _ = try std.posix.write(1, text);
    var held: [1]u8 = undefined;
    _ = try std.posix.read(try std.fmt.parseInt(i32, args[3], 10), &held);
}
