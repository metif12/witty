module internal_os

import log

#flag darwin -framework AppKit

#flag darwin -lobjc

#insert "@VMODROOT/internal_os/mouse_darwin.h"

fn C.witty_internal_os_click_interval(value &u32) int

// click_interval returns the system-configured double-click interval in
// milliseconds. This is the macOS branch of os.mouse.clickInterval.
pub fn click_interval() ?u32 {
	mut interval := u32(0)
	if C.witty_internal_os_click_interval(&interval) == 0 {
		log.error("NSEvent class not found. Can't get click interval.")
		return none
	}
	return interval
}
