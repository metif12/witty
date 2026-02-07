module inspector

// Inspector collects terminal inspection data for debugging.
pub struct Inspector {}

pub fn Inspector.init() !Inspector {
	return Inspector{}
}

pub fn (mut i Inspector) deinit() {}

pub fn (mut i Inspector) record_key_event(ev KeyEvent) bool {
	_ = ev
	return false
}

pub struct KeyEvent {
pub mut:
	event voidptr
}

pub fn (e KeyEvent) deinit() {}
