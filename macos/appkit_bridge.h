#include <stdbool.h>
#include <dispatch/dispatch.h>
#include <objc/message.h>
#include <Metal/Metal.h>
#include <objc/runtime.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>

typedef struct witty_macos_point {
	double x;
	double y;
} witty_macos_point;

typedef struct witty_macos_size {
	double width;
	double height;
} witty_macos_size;

typedef struct witty_macos_clear_color {
	double red;
	double green;
	double blue;
	double alpha;
} witty_macos_clear_color;

typedef struct witty_macos_string_task {
	void* view;
	char* text;
} witty_macos_string_task;

static inline bool witty_macos_is_main_thread(void) {
	return pthread_main_np() != 0;
}

static inline void witty_macos_dispatch_main(void* fn, void* ctx) {
	if (!fn) return;
	dispatch_async_f(dispatch_get_main_queue(), ctx, (dispatch_function_t)fn);
}

static inline witty_macos_string_task* witty_macos_string_task_new(void* view, char* text) {
	witty_macos_string_task* task = (witty_macos_string_task*)calloc(1, sizeof(witty_macos_string_task));
	if (!task) return NULL;
	task->view = view;
	if (text) {
		size_t len = strlen(text);
		task->text = (char*)malloc(len + 1);
		if (!task->text) {
			free(task);
			return NULL;
		}
		memcpy(task->text, text, len + 1);
	}
	return task;
}

static inline void witty_macos_string_task_free(witty_macos_string_task* task) {
	if (!task) return;
	free(task->text);
	free(task);
}

static inline witty_macos_point witty_macos_objc_msg_point0(void* obj, void* sel) {
	return ((witty_macos_point (*)(void*, void*))objc_msgSend)(obj, sel);
}

static inline witty_macos_point witty_macos_objc_msg_point_point_obj(void* obj, void* sel, witty_macos_point point, void* a1) {
	return ((witty_macos_point (*)(void*, void*, witty_macos_point, void*))objc_msgSend)(obj, sel, point, a1);
}

static inline bool witty_macos_objc_msg_bool2(void* obj, void* sel, void* a0, void* a1) {
	return ((bool (*)(void*, void*, void*, void*))objc_msgSend)(obj, sel, a0, a1);
}

static inline bool witty_macos_objc_msg_bool_u64(void* obj, void* sel, unsigned long long a0) {
	return ((bool (*)(void*, void*, unsigned long long))objc_msgSend)(obj, sel, a0);
}

static inline void witty_macos_objc_msg_void_size(void* obj, void* sel, witty_macos_size size) {
	((void (*)(void*, void*, witty_macos_size))objc_msgSend)(obj, sel, size);
}

static inline void witty_macos_objc_msg_void_clear_color(void* obj, void* sel, witty_macos_clear_color color) {
	((void (*)(void*, void*, witty_macos_clear_color))objc_msgSend)(obj, sel, color);
}

static inline void* witty_metal_new_buffer_length(void* device, size_t length, unsigned long long options) {
	if (!device) return NULL;
	return ((void* (*)(void*, SEL, unsigned long, unsigned long long))objc_msgSend)(
		device,
		sel_registerName("newBufferWithLength:options:"),
		(unsigned long)length,
		options
	);
}

static inline void* witty_metal_new_buffer_bytes(void* device, const void* bytes, size_t length, unsigned long long options) {
	if (!device || (!bytes && length != 0)) return NULL;
	return ((void* (*)(void*, SEL, const void*, unsigned long, unsigned long long))objc_msgSend)(
		device,
		sel_registerName("newBufferWithBytes:length:options:"),
		bytes,
		(unsigned long)length,
		options
	);
}

static inline size_t witty_metal_buffer_length(void* buffer) {
	if (!buffer) return 0;
	return ((unsigned long (*)(void*, SEL))objc_msgSend)(buffer, sel_registerName("length"));
}

static inline void* witty_metal_buffer_contents(void* buffer) {
	if (!buffer) return NULL;
	return ((void* (*)(void*, SEL))objc_msgSend)(buffer, sel_registerName("contents"));
}

static inline void witty_metal_buffer_did_modify(void* buffer, size_t length) {
	if (!buffer) return;
	NSRange range = NSMakeRange(0, length);
	((void (*)(void*, SEL, NSRange))objc_msgSend)(buffer, sel_registerName("didModifyRange:"), range);
}

static inline void* witty_metal_new_texture(
	void* device,
	unsigned long long pixel_format,
	size_t width,
	size_t height,
	unsigned long long resource_options,
	unsigned long long usage
) {
	if (!device || width == 0 || height == 0) return NULL;
	Class cls = objc_getClass("MTLTextureDescriptor");
	if (!cls) return NULL;
	void* desc = ((void* (*)(void*, SEL))objc_msgSend)((void*)cls, sel_registerName("alloc"));
	desc = ((void* (*)(void*, SEL))objc_msgSend)(desc, sel_registerName("init"));
	if (!desc) return NULL;
	((void (*)(void*, SEL, unsigned long long))objc_msgSend)(desc, sel_registerName("setPixelFormat:"), pixel_format);
	((void (*)(void*, SEL, unsigned long))objc_msgSend)(desc, sel_registerName("setWidth:"), (unsigned long)width);
	((void (*)(void*, SEL, unsigned long))objc_msgSend)(desc, sel_registerName("setHeight:"), (unsigned long)height);
	((void (*)(void*, SEL, unsigned long long))objc_msgSend)(desc, sel_registerName("setResourceOptions:"), resource_options);
	((void (*)(void*, SEL, unsigned long long))objc_msgSend)(desc, sel_registerName("setUsage:"), usage);
	void* texture = ((void* (*)(void*, SEL, void*))objc_msgSend)(device, sel_registerName("newTextureWithDescriptor:"), desc);
	((void (*)(void*, SEL))objc_msgSend)(desc, sel_registerName("release"));
	return texture;
}

static inline void witty_metal_texture_replace_region(
	void* texture,
	size_t x,
	size_t y,
	size_t width,
	size_t height,
	const void* bytes,
	size_t bytes_per_row
) {
	if (!texture || !bytes) return;
	MTLRegion region = MTLRegionMake2D((NSUInteger)x, (NSUInteger)y, (NSUInteger)width, (NSUInteger)height);
	((void (*)(void*, SEL, MTLRegion, unsigned long, const void*, unsigned long))objc_msgSend)(
		texture,
		sel_registerName("replaceRegion:mipmapLevel:withBytes:bytesPerRow:"),
		region,
		0,
		bytes,
		(unsigned long)bytes_per_row
	);
}

static inline void witty_metal_texture_get_bytes(
	void* texture,
	void* bytes,
	size_t bytes_per_row,
	size_t x,
	size_t y,
	size_t width,
	size_t height
) {
	if (!texture || !bytes) return;
	MTLRegion region = MTLRegionMake2D((NSUInteger)x, (NSUInteger)y, (NSUInteger)width, (NSUInteger)height);
	((void (*)(void*, SEL, void*, unsigned long, MTLRegion, unsigned long))objc_msgSend)(
		texture,
		sel_registerName("getBytes:bytesPerRow:fromRegion:mipmapLevel:"),
		bytes,
		(unsigned long)bytes_per_row,
		region,
		0
	);
}
