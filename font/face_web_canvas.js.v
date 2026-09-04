module font

fn web_canvas_platform_create() !voidptr {
	mut result := voidptr(0)
	#result = new voidptr(document.createElement('canvas'));
	return result
}

fn web_canvas_platform_destroy(mut canvas voidptr) {
	#canvas.val.width = 0;
	#canvas.val.height = 0;
	#canvas.val = null;
}

fn web_canvas_platform_measure(canvas voidptr, font_value string, text string) !WebCanvasMeasurement {
	mut result := WebCanvasMeasurement{}
	#const ctx = canvas.val.getContext('2d');
	#ctx.clearRect(0, 0, canvas.val.width, canvas.val.height);
	#ctx.font = font_value.str;
	#const metrics = ctx.measureText(text.str);
	#result.width = new f64(metrics.width || 0);
	#result.right = new f64(metrics.actualBoundingBoxRight || 0);
	#result.left = new f64(metrics.actualBoundingBoxLeft || 0);
	#result.ascent = new f64(metrics.actualBoundingBoxAscent || 0);
	#result.descent = new f64(metrics.actualBoundingBoxDescent || 0);
	return result
}

fn web_canvas_platform_render(canvas voidptr, font_value string, text string, width u32, height u32, left f64, ascent f64, broken_bbox bool) ![]u8 {
	mut bitmap := []u8{len: int(width * height * 4)}
	#const w = width.valueOf();
	#const h = height.valueOf();
	#canvas.val.width = w;
	#canvas.val.height = h;
	#canvas.val.style.width = `${w}px`;
	#canvas.val.style.height = `${h}px`;
	#const ctx = canvas.val.getContext('2d');
	#ctx.font = font_value.str;
	#if (broken_bbox.valueOf()) ctx.textBaseline = 'ideographic';
	#ctx.clearRect(0, 0, w, h);
	#ctx.fillStyle = 'transparent';
	#ctx.fillRect(0, 0, w, h);
	#ctx.fillStyle = 'black';
	#ctx.fillText(text.str, left.valueOf() + 1, broken_bbox.valueOf() ? h : ascent.valueOf() + 1);
	#const src = ctx.getImageData(0, 0, w, h).data;
	#for (let i = 0; i < src.length; i++) bitmap.arr.arr[i] = new u8(src[i]);
	return bitmap
}

fn web_canvas_platform_debug(canvas voidptr) {
	#const element = document.getElementById('face-canvas');
	#if (element) element.append(canvas.val);
}
