// A library for injecting failures into V code for the express
// purpose of testing error handling paths.
//
// Improper error cleanup is one of the highest sources of bugs in code.
// Many error handling points are hard to exercise in unit tests and rare
// to encounter in production, so they often hide bugs. Worse, error
// scenarios are most likely to put your code in an unexpected state
// that can result in future assertion failures or memory safety issues.
//
// This module aims to solve this problem by providing a way to inject
// errors at specific points in your code during unit tests, allowing you
// to test every possible error path.
//
// # Usage
//
// Create a Tripwire instance for each failable function you want to test.
// The fail points are identified by string keys.
//
// Pepper your function with `tw.check("point_name")!` calls wherever you
// want to have a testable failure point. You don't need every error-prone
// call to have an associated tripwire check, only the ones you care about
// testing. Usually, this is going to be the points where you want to test
// cleanup logic above it.
//
// In unit tests, add `tw.error_always()` or related calls to configure
// expected failures. Then, call your function. Finally, always call
// `tw.end(.reset)!` to verify your expectations were met and to reset
// the tripwire for future tests.
//
// ```v
// mut tw := tripwire.new()
//
// fn my_function(mut tw tripwire.TripwireModule) !void {
//     tw.check('alloc_buf')!
//     buf := allocator.alloc(u8, 1024)!
//     errdefer allocator.free(buf)
//
//     tw.check('open_file')!
//     file := os.open('foo.txt')!
//     // ...
// }
//
// fn test_my_function_fails_on_alloc() {
//     mut tw := tripwire.new()
//     tw.error_always('alloc_buf', error('OutOfMemory'))
//     if _ := my_function(mut tw) {
//         assert false, 'expected error'
//     }
//     tw.end(.reset) or { assert false }
// }
// ```
//
// ## Transitive Function Calls
//
// To test transitive calls, there are two schools of thought:
//
//   1. Put a failure point above the transitive call in the caller
//      and assume the child function error handling works correctly.
//
//   2. Create another tripwire module for the child function and
//      trigger failures there. This is recommended if the child function
//      can't really be called in isolation (e.g. its an auxiliary function
//      to a public API).
//
// Either works, its situationally dependent which is better.

module tripwire

// Future ideas:
//
//   - Assert that the errors are actually tripped. e.g. you set a
//     error_always on a point, and want to verify it was tripped.
//   - Assert that every point is covered by at least one test. We
//     can probably use global state for this.
//   - Error only after a certain number of calls to a point.
//   - Error only on a range of calls (first 5 times, 2-7th time, etc.)
//
// I don't want to implement these until they're actually needed by
// some part of our codebase, but I want to list them here in case they
// do become useful.

// ResetMode specifies whether expectations are reset when ending.
pub enum ResetMode {
	reset
	retain
}

// Tripwire stores the configuration for a single fail point.
struct Tripwire {
mut:
	// Error to return when tripped
	err IError
	// The amount of times this tripwire has been reached. This
	// is NOT the number of times it has tripped, since we may
	// have mins for that.
	reached int
	// The minimum number of times this must be reached before
	// tripping. After this point, it trips every time. This is
	// a "before" check so if this is "1" then it'll trip the
	// second time it's reached.
	min int
	// True if this has been tripped at least once.
	tripped bool
}

// TripwireModule is a tripwire module that can be used to inject failures
// at specific points.
//
// To use this module, add `check` calls prior to every error-prone
// operation that you want to be able to fail arbitrarily. Then,
// in your unit tests, call the `error` family of functions to configure
// when errors should be injected.
//
// The fail points are identified by string keys.
pub struct TripwireModule {
mut:
	// The configured tripwires for this module.
	tripwires map[string]Tripwire
}

// new creates a new TripwireModule.
pub fn new() TripwireModule {
	return TripwireModule{}
}

// check checks for a failure at the given failure point. These should
// be placed directly before the operation that may fail.
// Returns an error if the tripwire is configured to trip at this point.
pub fn (mut self TripwireModule) check(point string) ! {
	if point !in self.tripwires {
		return
	}
	mut tw := self.tripwires[point]
	tw.reached += 1
	if tw.reached <= tw.min {
		self.tripwires[point] = tw
		return
	}
	tw.tripped = true
	self.tripwires[point] = tw
	return tw.err
}

// error_always marks a failure point to always trip with the given error.
pub fn (mut self TripwireModule) error_always(point string, err IError) {
	self.error_after(point, err, 0)
}

// error_after marks a failure point to trip with the given error after
// the failure point is reached at least `min` times. A value of
// zero is equivalent to `error_always`.
pub fn (mut self TripwireModule) error_after(point string, err IError, min int) {
	self.tripwires[point] = Tripwire{
		err: err
		min: min
	}
}

// end ends the tripwire session. This will raise an error if there
// were untripped error expectations. The reset mode specifies
// whether expectations are reset too. Expectations are always reset,
// even if this returns an error.
pub fn (mut self TripwireModule) end(reset_mode ResetMode) ! {
	mut untripped := false
	for key, tw in self.tripwires {
		if !tw.tripped {
			eprintln('tripwire: untripped point=${key}')
			untripped = true
		}
	}

	match reset_mode {
		.reset { self.reset() }
		.retain {}
	}

	if untripped {
		return error('UntrippedError')
	}
}

// reset unsets all the tripwires. You should usually call `end` instead.
pub fn (mut self TripwireModule) reset() {
	self.tripwires = map[string]Tripwire{}
}
