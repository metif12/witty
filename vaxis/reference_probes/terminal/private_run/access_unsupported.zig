const Terminal=@import("widgets/terminal/Terminal.zig");
pub fn main()!void{
    var terminal:Terminal=undefined;
    try terminal.run();
}
