module benchmark

import time

// BenchmarkStepFn is one measured invocation of a benchmark implementation.
pub type BenchmarkStepFn = fn (voidptr) !

// BenchmarkSetupFn prepares a benchmark before timing begins.
pub type BenchmarkSetupFn = fn (voidptr) !

// BenchmarkTeardownFn releases state after timing ends, including on failure.
pub type BenchmarkTeardownFn = fn (voidptr)

// VTable contains the implementation callbacks for a Benchmark. It is the V
// translation of Benchmark.VTable; V function aliases replace Zig's typed
// anyopaque function pointers.
pub struct VTable {
pub:
	step_fn     BenchmarkStepFn @[required]
	setup_fn    ?BenchmarkSetupFn
	teardown_fn ?BenchmarkTeardownFn
}

// RunModeTag identifies the active RunMode payload.
pub enum RunModeTag as u8 {
	once
	duration
}

// RunMode determines how long a benchmark runs. The duration payload is in
// nanoseconds, matching Benchmark.RunMode.duration.
pub struct RunMode {
pub:
	tag         RunModeTag
	nanoseconds u64
}

// once constructs a mode that executes exactly one step.
pub fn RunMode.once() RunMode {
	return RunMode{
		tag: .once
	}
}

// duration constructs a mode that executes steps until at least nanoseconds
// have elapsed. A running step is never interrupted.
pub fn RunMode.duration(nanoseconds u64) RunMode {
	return RunMode{
		tag:         .duration
		nanoseconds: nanoseconds
	}
}

// RunResult reports the number of completed steps and elapsed nanoseconds.
pub struct RunResult {
pub mut:
	iterations u32
	duration   u64
}

// Benchmark is a type-erased benchmark implementation and its callback table.
pub struct Benchmark {
pub:
	ptr    voidptr
	vtable VTable
}

// BenchmarkSignpost is populated only on Darwin. The platform-specific files
// turn it into the same Instruments interval used by Ghostty.
struct BenchmarkSignpost {
mut:
	log    voidptr
	id     u64
	active bool
}

// init creates a benchmark from an implementation pointer and callback table.
// Zig enforces the pointer-to-struct requirement at comptime; V's voidptr loses
// that type metadata, so the translated boundary can only reject null.
pub fn Benchmark.init(pointer voidptr, vtable VTable) Benchmark {
	if isnil(pointer) {
		panic('benchmark implementation pointer must not be nil')
	}
	return Benchmark{
		ptr:    pointer
		vtable: vtable
	}
}

// run executes setup once, times one or more steps, and always tears down after
// successful setup. Callback failures are normalized to BenchmarkFailed just
// like Ghostty's closed Benchmark.Error set.
pub fn (self Benchmark) run(mode RunMode) !RunResult {
	if setup_fn := self.vtable.setup_fn {
		setup_fn(self.ptr) or { return error('benchmark failed') }
	}
	defer {
		if teardown_fn := self.vtable.teardown_fn {
			teardown_fn(self.ptr)
		}
	}

	mut signpost := benchmark_signpost_begin(self.ptr)
	defer {
		signpost.end()
	}

	start := time.sys_mono_now()
	mut result := RunResult{}
	for {
		self.vtable.step_fn(self.ptr) or { return error('benchmark failed') }
		result.iterations++

		now := time.sys_mono_now()
		elapsed := u64(now - start)
		exit := match mode.tag {
			.once { true }
			.duration { elapsed >= mode.nanoseconds }
		}

		if exit {
			result.duration = elapsed
			return result
		}
	}
	panic('unreachable benchmark loop exit')
}
