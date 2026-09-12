module kitty

import terminal

// Kitty keyboard protocol support.
//
// Source: kitty/key.zig
//
// The Kitty keyboard protocol allows terminal applications to receive
// enhanced keyboard input, including key disambiguation, event reporting,
// alternate key reporting, and associated text reporting.

// ============================================================
// Flags - possible flags for the Kitty keyboard protocol
// ============================================================

// The cycle-free terminal module owns the canonical translated value because
// other files in this V module import terminal for graphics storage.
pub type KeyFlags = terminal.KeyFlags

// Kitty keyboard protocol disabled (all flags off).
pub const key_flags_disabled = terminal.key_flags_disabled

// All modes on.
pub const key_flags_all = terminal.key_flags_all

// ============================================================
// SetMode - the possible modes for setting the key flags
// ============================================================

// The possible modes for setting the key flags via the CSI = u sequence.
pub type KeySetMode = terminal.KeyFlagSetOp

// ============================================================
// FlagStack - stack for the key flags
// ============================================================

// Stack for the key flags. This implements the push/pop behavior
// of the CSI > u and CSI < u sequences. We implement the stack as
// fixed size to avoid heap allocation.
pub type KeyFlagStack = terminal.KeyFlagStack
