module xev

$if !windows {
	pub type WasiWatcherCallback = fn (ud voidptr, l &WasiLoop, c &WasiCompletion, r ?ErrorKind) CallbackAction
}
