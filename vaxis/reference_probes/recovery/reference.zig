const std = @import("std");
const vaxis = @import("vaxis");
const a = std.heap.page_allocator;
fn raw(state: std.posix.termios) bool {
    return !state.lflag.ICANON and !state.lflag.ECHO and !state.lflag.ISIG and !state.iflag.ICRNL and !state.iflag.IXON and !state.oflag.OPOST;
}
fn initFails() !bool {
    const saved = try std.posix.getrlimit(.NOFILE);
    var limits = saved; limits.cur = 0; try std.posix.setrlimit(.NOFILE, limits);
    defer std.posix.setrlimit(.NOFILE, saved) catch @panic("restore rlimit");
    var buffer: [0]u8 = .{};
    _ = vaxis.Tty.init(&buffer) catch return true;
    return false;
}
pub fn main() !void {
    const args = try std.process.argsAlloc(a);
    const mode = args[1];
    const count = try std.fmt.parseInt(u16, args[2], 10);
    const size = try std.fmt.parseInt(u16, args[3], 10);
    const prefix = try std.fmt.parseInt(u16, args[4], 10);
    const original = try std.posix.tcgetattr(0);
    var expected = original;
    var fd: std.posix.fd_t = -1;
    var was_raw = false;
    var failed = false;
    const absent = std.mem.eql(u8, mode, "empty") or std.mem.eql(u8, mode, "panic_empty") or std.mem.eql(u8, mode, "none_fail");
    if (!absent) {
        const buffer = try a.alloc(u8, size);
        var tty = try vaxis.Tty.init(buffer);
        fd = tty.fd;
        was_raw = raw(try std.posix.tcgetattr(0));
        if (prefix != 0) { const data = try a.alloc(u8, prefix); @memset(data, 'P'); try tty.writer().writeAll(data); }
        if (std.mem.eql(u8, mode, "two") or std.mem.eql(u8, mode, "panic_two")) {
            const second_buffer = try a.alloc(u8, size);
            var second = try vaxis.Tty.init(second_buffer); fd = second.fd; _ = &second;
        }
        expected = vaxis.tty.global_tty.?.termios;
        if (std.mem.eql(u8, mode, "mutate") or std.mem.eql(u8, mode, "panic_mutate")) {
            tty.termios = try std.posix.tcgetattr(0); tty.fd = -1; tty.tty_writer.file.handle = -1;
        }
        if (std.mem.eql(u8, mode, "deinit")) tty.deinit();
        if (std.mem.eql(u8, mode, "fail_init")) failed = try initFails();
        if (std.mem.eql(u8, mode, "readonly") or std.mem.eql(u8, mode, "panic_readonly")) {
            const readonly = try std.posix.open("/dev/tty", .{ .ACCMODE = .RDONLY }, 0);
            try std.posix.dup2(readonly, fd); std.posix.close(readonly);
        }
    } else if (std.mem.eql(u8, mode, "none_fail")) failed = try initFails();
    if (std.mem.startsWith(u8, mode, "panic_")) {
        var ready_bytes: [64]u8 = undefined; var ready = std.fs.File.stdout().writer(&ready_bytes);
        try ready.interface.writeAll("READY\n"); try ready.interface.flush();
        if (std.mem.eql(u8, mode, "panic_call")) vaxis.Panic.call("recovery-proof", null, null);
        if (std.mem.eql(u8, mode, "panic_trace")) {
            var trace: std.builtin.StackTrace = .{ .index = 0, .instruction_addresses = &.{} };
            vaxis.panic_handler("recovery-proof", &trace, 0);
        }
        vaxis.panic_handler("recovery-proof", null, null);
    }
    for (0..count) |_| vaxis.recover();
    const current = try std.posix.tcgetattr(0);
    const snapshot = vaxis.tty.global_tty;
    const matches_fd = if (snapshot) |value| value.fd == fd else fd == -1;
    const matches_state = if (snapshot) |value| std.meta.eql(value.termios, expected) else true;
    const pending: usize = if (snapshot) |value| value.tty_writer.interface.end else 0;
    var bytes: [1024]u8 = undefined; var stdout = std.fs.File.stdout().writer(&bytes);
    try stdout.interface.print("{d},{d},{d},{d},{d},{d},{d},{d}\n", .{ @intFromBool(was_raw), @intFromBool(std.meta.eql(current, expected)), @intFromBool(std.meta.eql(current, original)), @intFromBool(snapshot != null), @intFromBool(matches_fd), @intFromBool(matches_state), pending, @intFromBool(failed) });
    try stdout.interface.flush();
    const release_fd = try std.fmt.parseInt(std.posix.fd_t, args[5], 10);
    var release: [1]u8 = undefined; _ = try std.posix.read(release_fd, &release);
}
