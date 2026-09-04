module internal_os

#flag darwin -framework AppKit

#flag darwin -lobjc

#insert "@VMODROOT/internal_os/mouse_darwin.h"

fn C.witty_internal_os_click_interval() u32

// click_interval returns the system-configured double-click interval in
// milliseconds. This is the Darwin branch of os.mouse.clickInterval.
pub fn click_interval() ?u32 {
	interval := C.witty_internal_os_click_interval()
	if interval == 0 {
		return none
	}
	return interval
}
