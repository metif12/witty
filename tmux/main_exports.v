module tmux

// Public alias exported by terminal/tmux.zig. The implementation type keeps
// the shorter control-module name because V flattens the source namespaces.
pub type ControlNotification = Notification
