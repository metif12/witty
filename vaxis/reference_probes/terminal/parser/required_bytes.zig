const ansi = @import("widgets/terminal/ansi.zig");
pub fn main() void {
    const iter = ansi.ParamIterator(u16){};
    _ = iter;
}
