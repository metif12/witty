const ansi = @import("widgets/terminal/ansi.zig");
pub fn main() void {
    var iter = ansi.ParamIterator(f32){.bytes="12"};
    _ = iter.next();
}
