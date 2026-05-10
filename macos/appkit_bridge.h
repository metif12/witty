#include <stdbool.h>
#include <objc/message.h>
#include <Metal/Metal.h>

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
