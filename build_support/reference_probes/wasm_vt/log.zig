const std = @import("std");
const builtin = @import("builtin");
const source = @import("source_log");
// The exact source lib_vt.zig std_options Wasm branch.
pub const std_options: std.Options = .{
    .log_level = switch (builtin.mode) {
        .Debug => .debug,
        .ReleaseSmall => .warn,
        else => .info,
    },
    .logFn = source.log,
};
export fn probe_log(index: u32) void {
    const test_log = std.log.scoped(.@"test");
    switch (index) {
        0 => std.log.err("failure", .{}),
        1 => std.log.scoped(.key_event).warn("warning", .{}),
        2 => test_log.info("information", .{}),
        3 => std.log.debug("details", .{}),
        4 => test_log.warn("{s}", .{"a" ** 2020}),
        5 => test_log.warn("{s}", .{"a" ** 3000}),
        else => unreachable,
    }
}
