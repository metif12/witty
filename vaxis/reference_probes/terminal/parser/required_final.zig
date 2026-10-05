const ansi = @import("widgets/terminal/ansi.zig");
pub fn main() void {
    const seq = ansi.CSI{.params=""};
    _ = seq;
}
