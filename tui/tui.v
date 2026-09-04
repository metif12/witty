module tui

// can_pretty_print is false on Apple platforms where terminal-style output is
// not appropriate, and true everywhere else. This mirrors cli/tui.zig.
pub const can_pretty_print = $if ios || tvos || watchos { false } $else { true }
