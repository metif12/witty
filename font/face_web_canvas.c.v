module font

fn web_canvas_platform_create() !voidptr {
	return error('WebCanvas is only available with the JavaScript backend')
}

fn web_canvas_platform_destroy(_ voidptr) {}

fn web_canvas_platform_measure(_ voidptr, _ string, _ string) !WebCanvasMeasurement {
	return error('WebCanvas is only available with the JavaScript backend')
}

fn web_canvas_platform_render(_ voidptr, _ string, _ string, _ u32, _ u32, _ f64, _ f64, _ bool) ![]u8 {
	return error('WebCanvas is only available with the JavaScript backend')
}

fn web_canvas_platform_debug(_ voidptr) {}
