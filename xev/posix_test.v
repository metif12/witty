module xev

// std.posix.ShutdownHow is an inferred three-case Zig enum. V's narrowest
// addressable representation is one byte.
fn test_posix_shutdown_how_matches_source_contract() {
	assert sizeof(ShutdownHow) == 1
	assert u8(ShutdownHow.recv) == 0
	assert u8(ShutdownHow.send) == 1
	assert u8(ShutdownHow.both) == 2
}
