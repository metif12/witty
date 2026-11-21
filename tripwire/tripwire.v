module tripwire

// enabled mirrors Ghostty's test-only tripwire specialization.
pub const enabled = $if test { true } $else { false }

pub enum ResetMode as u8 {
	reset
	retain
}

struct Tripwire {
mut:
	err     IError
	reached uint
	min     uint
	tripped bool
}

// TripwireModule injects test-only failures at the typed points P.
pub struct TripwireModule[P] {
mut:
	tripwires map[P]Tripwire
}

pub fn new[P]() TripwireModule[P] {
	return TripwireModule[P]{}
}

// check returns the configured error after its minimum reach count.
pub fn (mut self TripwireModule[P]) check(point P) ! {
	$if test {
		if point !in self.tripwires {
			return
		}
		mut value := self.tripwires[point]
		value.reached++
		if value.reached <= value.min {
			self.tripwires[point] = value
			return
		}
		value.tripped = true
		self.tripwires[point] = value
		return value.err
	} $else {
		_ = point
	}
}

// check_constrained is Ghostty's narrowed-error-set check. V errors are
// already untyped, so this has the same runtime contract as check.
pub fn (mut self TripwireModule[P]) check_constrained(point P) ! {
	self.check(point)!
}

// error_always marks point to fail every time it is checked.
pub fn (mut self TripwireModule[P]) error_always(point P, err IError) {
	self.error_after(point, err, 0)
}

// error_after marks point to fail after it has been reached min times.
pub fn (mut self TripwireModule[P]) error_after(point P, err IError, min uint) {
	self.tripwires[point] = Tripwire{
		err: err
		min: min
	}
}

// end reports untripped expectations and optionally resets the module.
pub fn (mut self TripwireModule[P]) end(reset_mode ResetMode) ! {
	mut untripped := false
	for point, value in self.tripwires {
		if !value.tripped {
			eprintln('tripwire: untripped point=${point}')
			untripped = true
		}
	}
	if reset_mode == .reset {
		self.reset()
	}
	if untripped {
		return error('UntrippedError')
	}
}

// reset removes every configured tripwire.
pub fn (mut self TripwireModule[P]) reset() {
	self.tripwires = map[P]Tripwire{}
}
