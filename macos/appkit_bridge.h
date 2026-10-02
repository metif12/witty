#include <stdbool.h>
#include <dispatch/dispatch.h>
#include <objc/message.h>
#include <Metal/Metal.h>
#include <QuartzCore/QuartzCore.h>
#include <IOSurface/IOSurface.h>
#include <objc/runtime.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>

static inline void witty_macos_observe(void* center, void* observer, void* selector, void* name, void* object) {
	((void (*)(id, SEL, id, SEL, id, id))objc_msgSend)((id)center, sel_registerName("addObserver:selector:name:object:"), (id)observer, (SEL)selector, (id)name, (id)object);
}

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

typedef struct witty_metal_vertex_attribute {
	unsigned long long format;
	size_t offset;
} witty_metal_vertex_attribute;

typedef struct witty_metal_pipeline_attachment {
	unsigned long long pixel_format;
	bool blending_enabled;
} witty_metal_pipeline_attachment;

typedef void (*witty_metal_layer_display_callback)(void*);

typedef void (*witty_metal_command_buffer_completion_callback)(
	void*,
	void*,
	unsigned long long,
	bool
);

/*
 * Minimal Objective-C block ABI used by MTLCommandBuffer's
 * addCompletedHandler:. The block captures only raw pointers, so it needs no
 * copy/dispose helpers; Metal copies the stack block before this function
 * returns and releases that copy after invocation.
 */
typedef struct witty_block_descriptor {
	unsigned long reserved;
	unsigned long size;
} witty_block_descriptor;

typedef struct witty_metal_completion_block {
	void* isa;
	int flags;
	int reserved;
	void (*invoke)(struct witty_metal_completion_block*, void*);
	const witty_block_descriptor* descriptor;
	witty_metal_command_buffer_completion_callback callback;
	void* renderer;
	void* target;
} witty_metal_completion_block;

extern void* _NSConcreteStackBlock[32];

static const witty_block_descriptor witty_metal_completion_descriptor = {
	0,
	sizeof(witty_metal_completion_block),
};

typedef struct witty_ns_operating_system_version {
	long long major;
	long long minor;
	long long patch;
} witty_ns_operating_system_version;

static inline bool witty_macos_is_at_least_version(long long major, long long minor, long long patch) {
	Class cls = objc_getClass("NSProcessInfo");
	if (!cls) return false;
	id info = ((id (*)(id, SEL))objc_msgSend)((id)cls, sel_registerName("processInfo"));
	if (!info) return false;
	witty_ns_operating_system_version version = { major, minor, patch };
	return ((bool (*)(id, SEL, witty_ns_operating_system_version))objc_msgSend)(
		info,
		sel_registerName("isOperatingSystemAtLeastVersion:"),
		version
	);
}

// Returns an owned UTF-8 copy of NSFileManager's user-domain directory path.
// The caller must release it with free().
static inline char* witty_macos_user_directory(unsigned long directory) {
	Class pool_cls = objc_getClass("NSAutoreleasePool");
	id pool = pool_cls
		? ((id (*)(id, SEL))objc_msgSend)(
			((id (*)(id, SEL))objc_msgSend)((id)pool_cls, sel_registerName("alloc")),
			sel_registerName("init")
		)
		: nil;
	Class manager_cls = objc_getClass("NSFileManager");
	id manager = manager_cls
		? ((id (*)(id, SEL))objc_msgSend)((id)manager_cls, sel_registerName("defaultManager"))
		: nil;
	id url = manager
		? ((id (*)(id, SEL, unsigned long, unsigned long, id, bool, id*))objc_msgSend)(
			manager,
			sel_registerName("URLForDirectory:inDomain:appropriateForURL:create:error:"),
			directory,
			1ul,
			nil,
			true,
			nil
		)
		: nil;
	id path = url
		? ((id (*)(id, SEL))objc_msgSend)(url, sel_registerName("path"))
		: nil;
	const char* utf8 = path
		? ((const char* (*)(id, SEL))objc_msgSend)(path, sel_registerName("UTF8String"))
		: NULL;
	char* result = utf8 ? strdup(utf8) : NULL;
	if (pool) ((void (*)(id, SEL))objc_msgSend)(pool, sel_registerName("drain"));
	return result;
}

// Private CoreGraphics APIs used by Terminal.app and other terminals to set
// the blur radius behind a translucent NSWindow.
extern void* CGSDefaultConnectionForThread(void);
extern int CGSSetWindowBackgroundBlurRadius(void*, size_t, int);

static inline void witty_macos_set_window_background_blur(void* window, int radius) {
	if (!window) return;
	SEL selector = sel_registerName("windowNumber");
	size_t window_number = ((size_t (*)(id, SEL))objc_msgSend)((id)window, selector);
	(void)CGSSetWindowBackgroundBlurRadius(
		CGSDefaultConnectionForThread(),
		window_number,
		radius
	);
}

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

static inline void* witty_macos_objc_msg_id_rect_u64_obj_obj(
	void* obj,
	void* selector,
	macos_rect rect,
	unsigned long long options,
	void* owner,
	void* user_info
) {
	return ((void* (*)(void*, void*, macos_rect, unsigned long long, void*, void*))objc_msgSend)(
		obj,
		selector,
		rect,
		options,
		owner,
		user_info
	);
}

static inline Class witty_macos_objc_superclass(void* obj) {
	if (!obj) return Nil;
	return class_getSuperclass(object_getClass((id)obj));
}

static inline bool witty_macos_objc_msg_super_bool0(void* obj, void* selector) {
	Class superclass = witty_macos_objc_superclass(obj);
	if (!superclass) return false;
	struct objc_super info = { (id)obj, superclass };
	return ((bool (*)(struct objc_super*, SEL))objc_msgSendSuper)(&info, (SEL)selector);
}

static inline void witty_macos_objc_msg_super_void0(void* obj, void* selector) {
	Class superclass = witty_macos_objc_superclass(obj);
	if (!superclass) return;
	struct objc_super info = { (id)obj, superclass };
	((void (*)(struct objc_super*, SEL))objc_msgSendSuper)(&info, (SEL)selector);
}

static inline void witty_macos_objc_msg_super_void1(void* obj, void* selector, void* value) {
	Class superclass = witty_macos_objc_superclass(obj);
	if (!superclass) return;
	struct objc_super info = { (id)obj, superclass };
	((void (*)(struct objc_super*, SEL, void*))objc_msgSendSuper)(&info, (SEL)selector, value);
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

static inline void witty_metal_command_buffer_commit(void* command_buffer) {
	if (!command_buffer) return;
	((void (*)(void*, SEL))objc_msgSend)(command_buffer, sel_registerName("commit"));
}

static inline void witty_metal_command_buffer_wait(void* command_buffer) {
	if (!command_buffer) return;
	((void (*)(void*, SEL))objc_msgSend)(command_buffer, sel_registerName("waitUntilCompleted"));
}

static inline unsigned long long witty_metal_command_buffer_status(void* command_buffer) {
	if (!command_buffer) return 5;
	return ((unsigned long long (*)(void*, SEL))objc_msgSend)(command_buffer, sel_registerName("status"));
}

static inline void witty_metal_command_buffer_completion_invoke(
	witty_metal_completion_block* block,
	void* command_buffer
) {
	if (!block || !block->callback) return;
	block->callback(
		block->renderer,
		block->target,
		witty_metal_command_buffer_status(command_buffer),
		false
	);
}

static inline bool witty_metal_command_buffer_add_completed_handler(
	void* command_buffer,
	witty_metal_command_buffer_completion_callback callback,
	void* renderer,
	void* target
) {
	if (!command_buffer || !callback) return false;
	witty_metal_completion_block block = {
		_NSConcreteStackBlock,
		0,
		0,
		witty_metal_command_buffer_completion_invoke,
		&witty_metal_completion_descriptor,
		callback,
		renderer,
		target,
	};
	((void (*)(void*, SEL, void*))objc_msgSend)(
		command_buffer,
		sel_registerName("addCompletedHandler:"),
		&block
	);
	return true;
}

static inline void witty_metal_command_buffer_invoke_completion(
	void* command_buffer,
	witty_metal_command_buffer_completion_callback callback,
	void* renderer,
	void* target,
	bool sync
) {
	if (!command_buffer || !callback) return;
	callback(
		renderer,
		target,
		witty_metal_command_buffer_status(command_buffer),
		sync
	);
}

static inline void* witty_metal_render_pass_descriptor(void) {
	Class cls = objc_getClass("MTLRenderPassDescriptor");
	if (!cls) return NULL;
	return ((void* (*)(void*, SEL))objc_msgSend)((void*)cls, sel_registerName("renderPassDescriptor"));
}

static inline void witty_metal_render_pass_set_attachment(
	void* descriptor,
	unsigned long index,
	void* texture,
	bool has_clear_color,
	witty_macos_clear_color color
) {
	if (!descriptor || !texture) return;
	void* attachments = ((void* (*)(void*, SEL))objc_msgSend)(descriptor, sel_registerName("colorAttachments"));
	void* attachment = ((void* (*)(void*, SEL, unsigned long))objc_msgSend)(attachments, sel_registerName("objectAtIndexedSubscript:"), index);
	((void (*)(void*, SEL, unsigned long long))objc_msgSend)(attachment, sel_registerName("setLoadAction:"), has_clear_color ? 2ull : 1ull);
	((void (*)(void*, SEL, unsigned long long))objc_msgSend)(attachment, sel_registerName("setStoreAction:"), 1ull);
	((void (*)(void*, SEL, void*))objc_msgSend)(attachment, sel_registerName("setTexture:"), texture);
	if (has_clear_color) {
		MTLClearColor clear = MTLClearColorMake(color.red, color.green, color.blue, color.alpha);
		((void (*)(void*, SEL, MTLClearColor))objc_msgSend)(attachment, sel_registerName("setClearColor:"), clear);
	}
}

static inline void witty_metal_encoder_set_pipeline(void* encoder, void* pipeline) {
	if (!encoder || !pipeline) return;
	((void (*)(void*, SEL, void*))objc_msgSend)(encoder, sel_registerName("setRenderPipelineState:"), pipeline);
}

static inline void witty_metal_encoder_set_buffer(void* encoder, void* buffer, unsigned long index) {
	if (!encoder || !buffer) return;
	((void (*)(void*, SEL, void*, unsigned long, unsigned long))objc_msgSend)(encoder, sel_registerName("setVertexBuffer:offset:atIndex:"), buffer, 0, index);
	((void (*)(void*, SEL, void*, unsigned long, unsigned long))objc_msgSend)(encoder, sel_registerName("setFragmentBuffer:offset:atIndex:"), buffer, 0, index);
}

static inline void witty_metal_encoder_set_texture(void* encoder, void* texture, unsigned long index) {
	if (!encoder || !texture) return;
	((void (*)(void*, SEL, void*, unsigned long))objc_msgSend)(encoder, sel_registerName("setVertexTexture:atIndex:"), texture, index);
	((void (*)(void*, SEL, void*, unsigned long))objc_msgSend)(encoder, sel_registerName("setFragmentTexture:atIndex:"), texture, index);
}

static inline void witty_metal_encoder_set_sampler(void* encoder, void* sampler, unsigned long index) {
	if (!encoder || !sampler) return;
	((void (*)(void*, SEL, void*, unsigned long))objc_msgSend)(encoder, sel_registerName("setFragmentSamplerState:atIndex:"), sampler, index);
}

static inline void witty_metal_encoder_draw(
	void* encoder,
	unsigned long long primitive,
	unsigned long vertex_count,
	unsigned long instance_count
) {
	if (!encoder || instance_count == 0) return;
	((void (*)(void*, SEL, unsigned long long, unsigned long, unsigned long, unsigned long))objc_msgSend)(
		encoder,
		sel_registerName("drawPrimitives:vertexStart:vertexCount:instanceCount:"),
		primitive,
		0,
		vertex_count,
		instance_count
	);
}

static inline void* witty_metal_new_sampler(
	void* device,
	unsigned long long min_filter,
	unsigned long long mag_filter,
	unsigned long long s_address_mode,
	unsigned long long t_address_mode
) {
	if (!device) return NULL;
	Class cls = objc_getClass("MTLSamplerDescriptor");
	if (!cls) return NULL;
	void* desc = ((void* (*)(void*, SEL))objc_msgSend)((void*)cls, sel_registerName("alloc"));
	desc = ((void* (*)(void*, SEL))objc_msgSend)(desc, sel_registerName("init"));
	if (!desc) return NULL;
	((void (*)(void*, SEL, unsigned long long))objc_msgSend)(desc, sel_registerName("setMinFilter:"), min_filter);
	((void (*)(void*, SEL, unsigned long long))objc_msgSend)(desc, sel_registerName("setMagFilter:"), mag_filter);
	((void (*)(void*, SEL, unsigned long long))objc_msgSend)(desc, sel_registerName("setSAddressMode:"), s_address_mode);
	((void (*)(void*, SEL, unsigned long long))objc_msgSend)(desc, sel_registerName("setTAddressMode:"), t_address_mode);
	void* sampler = ((void* (*)(void*, SEL, void*))objc_msgSend)(device, sel_registerName("newSamplerStateWithDescriptor:"), desc);
	((void (*)(void*, SEL))objc_msgSend)(desc, sel_registerName("release"));
	return sampler;
}

static inline void* witty_metal_new_iosurface_texture(
	void* device,
	void* surface,
	unsigned long long pixel_format,
	size_t width,
	size_t height,
	unsigned long long resource_options,
	unsigned long long usage
) {
	if (!device || !surface || width == 0 || height == 0) return NULL;
	Class cls = objc_getClass("MTLTextureDescriptor");
	if (!cls) return NULL;
	void* desc = ((void* (*)(void*, SEL))objc_msgSend)((void*)cls, sel_registerName("alloc"));
	desc = ((void* (*)(void*, SEL))objc_msgSend)(desc, sel_registerName("init"));
	if (!desc) return NULL;
	((void (*)(void*, SEL, unsigned long))objc_msgSend)(desc, sel_registerName("setWidth:"), (unsigned long)width);
	((void (*)(void*, SEL, unsigned long))objc_msgSend)(desc, sel_registerName("setHeight:"), (unsigned long)height);
	((void (*)(void*, SEL, unsigned long long))objc_msgSend)(desc, sel_registerName("setPixelFormat:"), pixel_format);
	((void (*)(void*, SEL, unsigned long long))objc_msgSend)(desc, sel_registerName("setUsage:"), usage);
	((void (*)(void*, SEL, unsigned long long))objc_msgSend)(desc, sel_registerName("setResourceOptions:"), resource_options);
	void* texture = ((void* (*)(void*, SEL, void*, void*, unsigned long))objc_msgSend)(device, sel_registerName("newTextureWithDescriptor:iosurface:plane:"), desc, surface, 0);
	((void (*)(void*, SEL))objc_msgSend)(desc, sel_registerName("release"));
	return texture;
}

static inline void* witty_metal_nsstring(const char* bytes, size_t length) {
	if (!bytes) return NULL;
	Class cls = objc_getClass("NSString");
	if (!cls) return NULL;
	void* value = ((void* (*)(void*, SEL))objc_msgSend)((void*)cls, sel_registerName("alloc"));
	return ((void* (*)(void*, SEL, const void*, unsigned long, unsigned long))objc_msgSend)(
		value,
		sel_registerName("initWithBytes:length:encoding:"),
		bytes,
		(unsigned long)length,
		4
	);
}

static inline void* witty_metal_new_library_source(void* device, const char* source, size_t length) {
	if (!device || !source) return NULL;
	void* string = witty_metal_nsstring(source, length);
	if (!string) return NULL;
	void* error = NULL;
	void* library = ((void* (*)(void*, SEL, void*, void*, void**))objc_msgSend)(device, sel_registerName("newLibraryWithSource:options:error:"), string, NULL, &error);
	((void (*)(void*, SEL))objc_msgSend)(string, sel_registerName("release"));
	return library;
}

static inline void* witty_metal_new_pipeline(
	void* device,
	void* vertex_library,
	void* fragment_library,
	const char* vertex_name,
	size_t vertex_name_length,
	const char* fragment_name,
	size_t fragment_name_length,
	const witty_metal_vertex_attribute* attributes,
	size_t attribute_count,
	size_t vertex_stride,
	unsigned long long step_function,
	const witty_metal_pipeline_attachment* pipeline_attachments,
	size_t pipeline_attachment_count
) {
	if (!device || !vertex_library || !fragment_library || !vertex_name || !fragment_name) return NULL;
	void* vertex_string = witty_metal_nsstring(vertex_name, vertex_name_length);
	void* fragment_string = witty_metal_nsstring(fragment_name, fragment_name_length);
	if (!vertex_string || !fragment_string) {
		if (vertex_string) ((void (*)(void*, SEL))objc_msgSend)(vertex_string, sel_registerName("release"));
		if (fragment_string) ((void (*)(void*, SEL))objc_msgSend)(fragment_string, sel_registerName("release"));
		return NULL;
	}
	void* vertex_function = ((void* (*)(void*, SEL, void*))objc_msgSend)(vertex_library, sel_registerName("newFunctionWithName:"), vertex_string);
	void* fragment_function = ((void* (*)(void*, SEL, void*))objc_msgSend)(fragment_library, sel_registerName("newFunctionWithName:"), fragment_string);
	((void (*)(void*, SEL))objc_msgSend)(vertex_string, sel_registerName("release"));
	((void (*)(void*, SEL))objc_msgSend)(fragment_string, sel_registerName("release"));
	if (!vertex_function || !fragment_function) {
		if (vertex_function) ((void (*)(void*, SEL))objc_msgSend)(vertex_function, sel_registerName("release"));
		if (fragment_function) ((void (*)(void*, SEL))objc_msgSend)(fragment_function, sel_registerName("release"));
		return NULL;
	}

	Class pipeline_cls = objc_getClass("MTLRenderPipelineDescriptor");
	void* desc = ((void* (*)(void*, SEL))objc_msgSend)((void*)pipeline_cls, sel_registerName("alloc"));
	desc = ((void* (*)(void*, SEL))objc_msgSend)(desc, sel_registerName("init"));
	((void (*)(void*, SEL, void*))objc_msgSend)(desc, sel_registerName("setVertexFunction:"), vertex_function);
	((void (*)(void*, SEL, void*))objc_msgSend)(desc, sel_registerName("setFragmentFunction:"), fragment_function);

	void* vertex_desc = NULL;
	if (attribute_count > 0) {
		Class vertex_cls = objc_getClass("MTLVertexDescriptor");
		vertex_desc = ((void* (*)(void*, SEL))objc_msgSend)((void*)vertex_cls, sel_registerName("alloc"));
		vertex_desc = ((void* (*)(void*, SEL))objc_msgSend)(vertex_desc, sel_registerName("init"));
		void* attrs = ((void* (*)(void*, SEL))objc_msgSend)(vertex_desc, sel_registerName("attributes"));
		for (size_t i = 0; i < attribute_count; ++i) {
			void* attr = ((void* (*)(void*, SEL, unsigned long))objc_msgSend)(attrs, sel_registerName("objectAtIndexedSubscript:"), (unsigned long)i);
			((void (*)(void*, SEL, unsigned long long))objc_msgSend)(attr, sel_registerName("setFormat:"), attributes[i].format);
			((void (*)(void*, SEL, unsigned long))objc_msgSend)(attr, sel_registerName("setOffset:"), (unsigned long)attributes[i].offset);
			((void (*)(void*, SEL, unsigned long))objc_msgSend)(attr, sel_registerName("setBufferIndex:"), 0);
		}
		void* layouts = ((void* (*)(void*, SEL))objc_msgSend)(vertex_desc, sel_registerName("layouts"));
		void* layout = ((void* (*)(void*, SEL, unsigned long))objc_msgSend)(layouts, sel_registerName("objectAtIndexedSubscript:"), 0);
		((void (*)(void*, SEL, unsigned long long))objc_msgSend)(layout, sel_registerName("setStepFunction:"), step_function);
		((void (*)(void*, SEL, unsigned long))objc_msgSend)(layout, sel_registerName("setStride:"), (unsigned long)vertex_stride);
		((void (*)(void*, SEL, void*))objc_msgSend)(desc, sel_registerName("setVertexDescriptor:"), vertex_desc);
	}

	void* color_attachments = ((void* (*)(void*, SEL))objc_msgSend)(desc, sel_registerName("colorAttachments"));
	for (size_t i = 0; i < pipeline_attachment_count; ++i) {
		void* attachment = ((void* (*)(void*, SEL, unsigned long))objc_msgSend)(color_attachments, sel_registerName("objectAtIndexedSubscript:"), (unsigned long)i);
		((void (*)(void*, SEL, unsigned long long))objc_msgSend)(attachment, sel_registerName("setPixelFormat:"), pipeline_attachments[i].pixel_format);
		((void (*)(void*, SEL, bool))objc_msgSend)(attachment, sel_registerName("setBlendingEnabled:"), pipeline_attachments[i].blending_enabled);
		if (pipeline_attachments[i].blending_enabled) {
			((void (*)(void*, SEL, unsigned long long))objc_msgSend)(attachment, sel_registerName("setRgbBlendOperation:"), 0);
			((void (*)(void*, SEL, unsigned long long))objc_msgSend)(attachment, sel_registerName("setAlphaBlendOperation:"), 0);
			((void (*)(void*, SEL, unsigned long long))objc_msgSend)(attachment, sel_registerName("setSourceRGBBlendFactor:"), 1);
			((void (*)(void*, SEL, unsigned long long))objc_msgSend)(attachment, sel_registerName("setSourceAlphaBlendFactor:"), 1);
			((void (*)(void*, SEL, unsigned long long))objc_msgSend)(attachment, sel_registerName("setDestinationRGBBlendFactor:"), 5);
			((void (*)(void*, SEL, unsigned long long))objc_msgSend)(attachment, sel_registerName("setDestinationAlphaBlendFactor:"), 5);
		}
	}

	void* error = NULL;
	void* state = ((void* (*)(void*, SEL, void*, void**))objc_msgSend)(device, sel_registerName("newRenderPipelineStateWithDescriptor:error:"), desc, &error);
	if (vertex_desc) ((void (*)(void*, SEL))objc_msgSend)(vertex_desc, sel_registerName("release"));
	((void (*)(void*, SEL))objc_msgSend)(desc, sel_registerName("release"));
	((void (*)(void*, SEL))objc_msgSend)(vertex_function, sel_registerName("release"));
	((void (*)(void*, SEL))objc_msgSend)(fragment_function, sel_registerName("release"));
	return state;
}

static inline void witty_metal_iosurface_layer_display(void* target, SEL command) {
	(void)command;
	Ivar callback_ivar = class_getInstanceVariable(object_getClass(target), "display_cb");
	Ivar context_ivar = class_getInstanceVariable(object_getClass(target), "display_ctx");
	witty_metal_layer_display_callback callback = (witty_metal_layer_display_callback)object_getIvar(target, callback_ivar);
	void* context = object_getIvar(target, context_ivar);
	if (callback) callback(context);
}

static inline void* witty_metal_iosurface_layer_action(void* target, SEL command, void* key) {
	(void)target;
	(void)command;
	(void)key;
	Class cls = objc_getClass("NSNull");
	return cls ? ((void* (*)(void*, SEL))objc_msgSend)((void*)cls, sel_registerName("null")) : NULL;
}

static inline Class witty_metal_iosurface_layer_class(void) {
	static Class subclass = Nil;
	static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
	if (subclass) return subclass;
	pthread_mutex_lock(&lock);
	if (!subclass) {
		Class superclass = objc_getClass("CALayer");
		subclass = objc_allocateClassPair(superclass, "WittyIOSurfaceLayer", 0);
		if (!subclass) {
			subclass = objc_getClass("WittyIOSurfaceLayer");
		} else {
			class_addIvar(subclass, "display_cb", sizeof(void*), 3, "^v");
			class_addIvar(subclass, "display_ctx", sizeof(void*), 3, "^v");
			class_addMethod(subclass, sel_registerName("display"), (IMP)witty_metal_iosurface_layer_display, "v@:");
			class_addMethod(subclass, sel_registerName("actionForKey:"), (IMP)witty_metal_iosurface_layer_action, "@@:@");
			objc_registerClassPair(subclass);
		}
	}
	pthread_mutex_unlock(&lock);
	return subclass;
}

static inline void* witty_metal_iosurface_layer_new(void) {
	Class cls = witty_metal_iosurface_layer_class();
	if (!cls) return NULL;
	void* layer = ((void* (*)(void*, SEL))objc_msgSend)((void*)cls, sel_registerName("layer"));
	if (!layer) return NULL;
	((void (*)(void*, SEL))objc_msgSend)(layer, sel_registerName("retain"));
	Class string_cls = objc_getClass("NSString");
	void* gravity = ((void* (*)(void*, SEL, const char*))objc_msgSend)((void*)string_cls, sel_registerName("stringWithUTF8String:"), "topLeft");
	((void (*)(void*, SEL, void*))objc_msgSend)(layer, sel_registerName("setContentsGravity:"), gravity);
	return layer;
}

static inline void witty_metal_iosurface_layer_set_display_callback(void* layer, witty_metal_layer_display_callback callback, void* context) {
	if (!layer) return;
	Ivar callback_ivar = class_getInstanceVariable(object_getClass(layer), "display_cb");
	Ivar context_ivar = class_getInstanceVariable(object_getClass(layer), "display_ctx");
	object_setIvar(layer, callback_ivar, (void*)callback);
	object_setIvar(layer, context_ivar, context);
}

static inline void witty_metal_iosurface_layer_set_surface_sync(void* layer, void* surface) {
	if (!layer || !surface) return;
	((void (*)(void*, SEL, void*))objc_msgSend)(layer, sel_registerName("setContents:"), surface);
}

typedef struct witty_metal_layer_surface_task {
	void* layer;
	IOSurfaceRef surface;
} witty_metal_layer_surface_task;

static inline void witty_metal_iosurface_layer_set_surface_task(void* context) {
	witty_metal_layer_surface_task* task = (witty_metal_layer_surface_task*)context;
	CGRect bounds = ((CGRect (*)(void*, SEL))objc_msgSend)(task->layer, sel_registerName("bounds"));
	double scale = ((double (*)(void*, SEL))objc_msgSend)(task->layer, sel_registerName("contentsScale"));
	size_t width = (size_t)(bounds.size.width * scale);
	size_t height = (size_t)(bounds.size.height * scale);
	if (width == IOSurfaceGetWidth(task->surface) && height == IOSurfaceGetHeight(task->surface)) {
		witty_metal_iosurface_layer_set_surface_sync(task->layer, task->surface);
	}
	((void (*)(void*, SEL))objc_msgSend)(task->layer, sel_registerName("release"));
	CFRelease(task->surface);
	free(task);
}

static inline bool witty_metal_iosurface_layer_set_surface(void* layer, void* surface) {
	if (!layer || !surface) return false;
	witty_metal_layer_surface_task* task = (witty_metal_layer_surface_task*)calloc(1, sizeof(witty_metal_layer_surface_task));
	if (!task) return false;
	task->layer = ((void* (*)(void*, SEL))objc_msgSend)(layer, sel_registerName("retain"));
	task->surface = (IOSurfaceRef)CFRetain(surface);
	if (pthread_main_np() != 0) {
		witty_metal_iosurface_layer_set_surface_task(task);
	} else {
		dispatch_async_f(dispatch_get_main_queue(), task, witty_metal_iosurface_layer_set_surface_task);
	}
	return true;
}

/* ABI adapters for NSTextInputClient and NSEvent. Policy lives in V. */
typedef struct witty_macos_range { unsigned long location, length; } witty_macos_range;
static inline witty_macos_range witty_macos_msg_range(void* obj, void* selector) {
	return ((witty_macos_range (*)(id, SEL))objc_msgSend)((id)obj, (SEL)selector);
}
static inline void* witty_macos_msg_id_range(void* obj, void* selector, witty_macos_range range) {
	return ((void* (*)(id, SEL, witty_macos_range))objc_msgSend)((id)obj, (SEL)selector, range);
}
static inline void* witty_macos_msg_super_id2(void* obj, void* selector, void* a, void* b) {
	struct objc_super info = {(id)obj, witty_macos_objc_superclass(obj)};
	return ((void* (*)(struct objc_super*, SEL, id, id))objc_msgSendSuper)(&info, (SEL)selector, (id)a, (id)b);
}
static inline macos_rect witty_macos_msg_rect_rect_obj(void* obj, void* selector, macos_rect rect, void* other) {
	return ((macos_rect (*)(id, SEL, macos_rect, id))objc_msgSend)((id)obj, (SEL)selector, rect, (id)other);
}
static inline macos_rect witty_macos_msg_rect_rect(void* obj, void* selector, macos_rect rect) {
	return ((macos_rect (*)(id, SEL, macos_rect))objc_msgSend)((id)obj, (SEL)selector, rect);
}
static inline void* witty_macos_key_event(void* original, unsigned long long flags, void* chars, void* ignoring) {
	id event = (id)original;
	return ((void* (*)(id, SEL, unsigned long long, witty_macos_point, unsigned long long, double, long long, id, id, id, bool, unsigned short))objc_msgSend)(
		(id)objc_getClass("NSEvent"), sel_registerName("keyEventWithType:location:modifierFlags:timestamp:windowNumber:context:characters:charactersIgnoringModifiers:isARepeat:keyCode:"),
		((unsigned long long (*)(id, SEL))objc_msgSend)(event, sel_registerName("type")),
		((witty_macos_point (*)(id, SEL))objc_msgSend)(event, sel_registerName("locationInWindow")), flags,
		((double (*)(id, SEL))objc_msgSend)(event, sel_registerName("timestamp")),
		((long long (*)(id, SEL))objc_msgSend)(event, sel_registerName("windowNumber")), nil, (id)chars, (id)ignoring,
		((bool (*)(id, SEL))objc_msgSend)(event, sel_registerName("isARepeat")),
		((unsigned short (*)(id, SEL))objc_msgSend)(event, sel_registerName("keyCode")));
}

typedef void* (*witty_event_monitor_callback)(void*);
typedef struct witty_event_monitor_block {
	void* isa; int flags; int reserved;
	void* (*invoke)(struct witty_event_monitor_block*, void*);
	const witty_block_descriptor* descriptor;
	witty_event_monitor_callback callback;
} witty_event_monitor_block;
static void* witty_event_monitor_invoke(witty_event_monitor_block* block, void* event) { return block->callback(event); }
static const witty_block_descriptor witty_event_monitor_descriptor = {0, sizeof(witty_event_monitor_block)};
static inline void* witty_macos_monitor_key_releases(void* callback) {
	witty_event_monitor_block block = {_NSConcreteStackBlock, 0, 0, witty_event_monitor_invoke, &witty_event_monitor_descriptor, (witty_event_monitor_callback)callback};
	return ((void* (*)(id, SEL, unsigned long long, void*))objc_msgSend)((id)objc_getClass("NSEvent"), sel_registerName("addLocalMonitorForEventsMatchingMask:handler:"), 1ULL << 11, &block);
}
static inline void witty_macos_msg_super_from_void0(void* obj, void* defining_class, void* selector) {
	struct objc_super info = {(id)obj, class_getSuperclass((Class)defining_class)};
	((void (*)(struct objc_super*, SEL))objc_msgSendSuper)(&info, (SEL)selector);
}
static inline witty_macos_range witty_macos_msg_range_u64(void* obj, void* selector, unsigned long long index) {
	return ((witty_macos_range (*)(id, SEL, unsigned long long))objc_msgSend)((id)obj, (SEL)selector, index);
}

typedef struct witty_cache_timer_context {
	dispatch_source_t timer;
	void (*callback)(void*);
	void* context;
} witty_cache_timer_context;
static void witty_cache_timer_cancelled(void* raw) { free(raw); }
static void witty_cache_timer_fired(void* raw) {
	witty_cache_timer_context* ctx = raw;
	ctx->callback(ctx->context);
	dispatch_source_cancel(ctx->timer);
	dispatch_release(ctx->timer);
}
static inline void* witty_macos_cache_timer(unsigned long long duration, void* callback, void* context) {
	dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
	witty_cache_timer_context* ctx = malloc(sizeof(*ctx));
	ctx->timer = timer; ctx->callback = callback; ctx->context = context;
	dispatch_set_context(timer, ctx);
	dispatch_source_set_event_handler_f(timer, witty_cache_timer_fired);
	dispatch_source_set_cancel_handler_f(timer, witty_cache_timer_cancelled);
	dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, duration), DISPATCH_TIME_FOREVER, 0);
	dispatch_resume(timer);
	return timer;
}
static inline void witty_macos_cancel_timer(void* timer) {
	if (timer) { dispatch_source_cancel((dispatch_source_t)timer); dispatch_release((dispatch_source_t)timer); }
}
/* Public ICU character-break API exported by the macOS libicucore SDK. */
typedef struct UBreakIterator UBreakIterator;
extern UBreakIterator* ubrk_open(int32_t, const char*, const uint16_t*, int32_t, int32_t*);
extern int32_t ubrk_first(UBreakIterator*);
extern int32_t ubrk_next(UBreakIterator*);
extern void ubrk_close(UBreakIterator*);
static inline void witty_macos_copy_characters(void* string, uint16_t* output, unsigned long length) {
	witty_macos_range range = {0, length};
	((void (*)(id, SEL, uint16_t*, witty_macos_range))objc_msgSend)((id)string, sel_registerName("getCharacters:range:"), output, range);
}
/* Swift [weak self] capture across a main-queue callback. */
extern id objc_initWeak(id*, id);
extern id objc_loadWeakRetained(id*);
extern void objc_destroyWeak(id*);
typedef struct witty_macos_weak_task {
	id object;
	dispatch_function_t callback;
} witty_macos_weak_task;
static void witty_macos_weak_task_run(void* raw) {
	witty_macos_weak_task* task = raw;
	id object = objc_loadWeakRetained(&task->object);
	if (object) {
		task->callback((void*)object);
		((void (*)(id, SEL))objc_msgSend)(object, sel_registerName("release"));
	}
	objc_destroyWeak(&task->object);
	free(task);
}
static inline void witty_macos_dispatch_main_weak(void* object, void* callback) {
	witty_macos_weak_task* task = calloc(1, sizeof(*task));
	if (!task) abort();
	objc_initWeak(&task->object, (id)object);
	task->callback = (dispatch_function_t)callback;
	dispatch_async_f(dispatch_get_main_queue(), task, witty_macos_weak_task_run);
}
