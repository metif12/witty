const ansi = @import("widgets/terminal/ansi.zig");
pub fn main() void {
    var iter = ansi.ParamIterator(bool){.bytes="12"};
    _ = iter.next();
}
