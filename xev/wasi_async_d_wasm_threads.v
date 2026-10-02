module xev

$if !windows {
	// watcher/async.zig returns an empty watcher for threaded WASI;
	// low-level async_notify remains available on the loop.
	pub struct WasiAsync {}
}
