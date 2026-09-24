module xev

// V translation of libxev's src/backend.zig (pinned 34fa508).

// The backend types.
pub enum Backend as u8 {
	io_uring
	epoll
	kqueue
	wasi_poll
	iocp
}

// Returns a recommend default backend from inspecting the system.
pub fn Backend.default() Backend {
	$if linux {
		return .io_uring
	} $else $if macos || ios {
		return .kqueue
	} $else $if freebsd {
		return .kqueue
	} $else $if wasm32_wasi {
		return .wasi_poll
	} $else $if windows {
		return .iocp
	} $else {
		$compile_error('no default backend for this target')
	}
}

// Candidate backends for this platform in priority order.
pub fn Backend.candidates() []Backend {
	$if linux {
		return [.io_uring, .epoll]
	} $else $if macos || ios {
		return [.kqueue]
	} $else $if freebsd {
		return [.kqueue]
	} $else $if wasm32_wasi {
		return [.wasi_poll]
	} $else $if windows {
		return [.iocp]
	} $else {
		$compile_error('no candidate backends for this target')
	}
}
