module tui

// can_pretty_print is false on Apple mobile targets where terminal-style
// output is not appropriate, and true everywhere else. V currently exposes
// iOS as its only mobile Apple target (there are no tvOS/watchOS targets).
pub const can_pretty_print = $if ios { false } $else { true }
