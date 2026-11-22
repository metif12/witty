#ifndef WITTY_CLI_PROCESS_ARGS_DARWIN_H
#define WITTY_CLI_PROCESS_ARGS_DARWIN_H

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
#include <objc/message.h>
#include <objc/runtime.h>
#endif
#include <stdlib.h>
#include <string.h>

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
static inline id witty_cli_process_arguments(void) {
	Class cls = objc_getClass("NSProcessInfo");
	if (!cls) return nil;
	id info = ((id (*)(id, SEL))objc_msgSend)(
		(id)cls,
		sel_registerName("processInfo")
	);
	if (!info) return nil;
	return ((id (*)(id, SEL))objc_msgSend)(
		info,
		sel_registerName("arguments")
	);
}
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
static inline size_t witty_cli_process_argument_count(void) {
	id values = witty_cli_process_arguments();
	if (!values) return 0;
	return ((unsigned long (*)(id, SEL))objc_msgSend)(
		values,
		sel_registerName("count")
	);
}
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
static inline char* witty_cli_process_argument_copy(size_t index) {
	id values = witty_cli_process_arguments();
	if (!values) return NULL;
	id value = ((id (*)(id, SEL, unsigned long))objc_msgSend)(
		values,
		sel_registerName("objectAtIndex:"),
		index
	);
	if (!value) return NULL;
	const char* utf8 = ((const char* (*)(id, SEL))objc_msgSend)(
		value,
		sel_registerName("UTF8String")
	);
	return utf8 ? strdup(utf8) : NULL;
}
#endif

#endif
