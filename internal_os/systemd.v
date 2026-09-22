module internal_os

// launched_by_systemd reports whether Linux systemd directly launched this
// process. Other operating systems never satisfy this predicate.
pub fn launched_by_systemd() bool {
	$if linux {
		return launched_by_systemd_linux()
	} $else {
		return false
	}
}

// ready tells systemd that startup or configuration reload has completed. It
// translates systemd.notify.ready; the nested source namespace is flattened
// into V's internal_os module.
pub fn ready() {
	$if linux {
		systemd_notify_send('READY=1')
	}
}

// reloading tells systemd that configuration reloading has started and
// includes the current monotonic timestamp.
pub fn reloading() {
	$if linux {
		systemd_notify_reloading_linux()
	}
}
