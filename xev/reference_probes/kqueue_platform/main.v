module main

import xev

fn main() {
	assert xev.backend() == .kqueue
	assert xev.Backend.default() == .kqueue
	assert xev.Backend.candidates() == [xev.Backend.kqueue]
	assert xev.available()
	mut loop := xev.Loop.init(xev.Options{}) or { panic(err) }
	defer { loop.deinit() }
	mut timer := xev.Timer.init() or { panic(err) }
	defer { timer.deinit() }
	mut process := xev.Process.init(1234) or { panic(err) }
	defer { process.deinit() }
	mut async := xev.Async.init() or { panic(err) }
	defer { async.deinit() }
	mut pool := xev.ThreadPool.init(xev.ThreadPoolConfig{ max_threads: 2 })
	defer {
		pool.shutdown()
		pool.deinit()
	}
	println(sizeof(xev.Kevent))
}
