module apprt

import macos

fn set_window_background_blur(window voidptr, radius i16) {
	macos.set_window_background_blur(window, radius)
}
