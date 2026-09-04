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

// systemd_notify_ready tells systemd that startup or configuration reload has
// completed. It is a no-op when systemd did not provide a notification socket.
pub fn systemd_notify_ready() {
	$if linux {
		systemd_notify_send('READY=1')
	}
}

// systemd_notify_reloading tells systemd that configuration reloading has
// started and includes the current monotonic timestamp.
pub fn systemd_notify_reloading() {
	$if linux {
		systemd_notify_reloading_linux()
	}
}
