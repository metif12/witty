#ifndef WITTY_OPENGL_CONSTANTS_H
#define WITTY_OPENGL_CONSTANTS_H

#include <stdint.h>
#include <string.h>
#include <glad/gl.h>

/*
 * Keep this header independent from platform GL headers. opengl.v declares
 * the core GL entry points itself; including platform GL headers here gives
 * the C compiler two declarations for the same function and breaks builds on
 * macOS. The OpenGL 4.3 entry points are resolved dynamically so this module
 * can still compile on platforms whose link-time GL library lacks them.
 */

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
extern unsigned int glGetError(void);
extern void glGetIntegerv(unsigned int pname, int *data);
extern const unsigned char *glGetStringi(unsigned int name, unsigned int index);
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
extern void glClearColor(float red, float green, float blue, float alpha);
extern void glClear(unsigned int mask);
extern void glDrawArrays(unsigned int mode, int first, int count);
extern void glDrawArraysInstanced(unsigned int mode, int first, int count, int primcount);
extern void glDrawElements(unsigned int mode, int count, unsigned int type, void *indices);
extern void glDrawElementsInstanced(unsigned int mode, int count, unsigned int type, void *indices, int primcount);
extern void glEnable(unsigned int cap);
extern void glDisable(unsigned int cap);
extern void glFrontFace(unsigned int mode);
extern void glBlendFunc(unsigned int sfactor, unsigned int dfactor);
extern void glViewport(int x, int y, int width, int height);
extern void glPixelStorei(unsigned int pname, int param);
extern void glFinish(void);
extern void glFlush(void);
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
extern void glGenBuffers(int n, unsigned int *buffers);
extern void glBindBuffer(unsigned int target, unsigned int buffer);
extern void glDeleteBuffers(int n, unsigned int *buffers);
extern void glBindBufferBase(unsigned int target, unsigned int index, unsigned int buffer);
extern void glBufferData(unsigned int target, intptr_t size, void *data, unsigned int usage);
extern void glBufferSubData(unsigned int target, intptr_t offset, intptr_t size, void *data);
extern void glVertexAttribPointer(unsigned int index, int size, unsigned int type, unsigned char normalized, int stride, void *pointer);
extern void glVertexAttribIPointer(unsigned int index, int size, unsigned int type, int stride, void *pointer);
extern void glEnableVertexAttribArray(unsigned int index);
extern void glVertexAttribDivisor(unsigned int index, unsigned int divisor);
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
extern void glActiveTexture(unsigned int texture);
extern void glGenTextures(int n, unsigned int *textures);
extern void glBindTexture(unsigned int target, unsigned int texture);
extern void glDeleteTextures(int n, unsigned int *textures);
extern void glGenerateMipmap(unsigned int target);
extern void glTexParameteri(unsigned int target, unsigned int pname, int param);
extern void glTexImage2D(unsigned int target, int level, int internalformat, int width, int height, int border, unsigned int format, unsigned int type, void *pixels);
extern void glTexSubImage2D(unsigned int target, int level, int xoffset, int yoffset, int width, int height, unsigned int format, unsigned int type, void *pixels);
extern void glCopyTexSubImage2D(unsigned int target, int level, int xoffset, int yoffset, int x, int y, int width, int height);
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
extern void glGenVertexArrays(int n, unsigned int *arrays);
extern void glBindVertexArray(unsigned int array);
extern void glDeleteVertexArrays(int n, unsigned int *arrays);
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
extern unsigned int glCreateShader(unsigned int type);
extern void glShaderSource(unsigned int shader, int count, unsigned char **string, int *length);
extern void glCompileShader(unsigned int shader);
extern void glGetShaderiv(unsigned int shader, unsigned int pname, int *params);
extern void glGetShaderInfoLog(unsigned int shader, int maxLength, int *length, unsigned char *infoLog);
extern void glDeleteShader(unsigned int shader);
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
extern unsigned int glCreateProgram(void);
extern void glDeleteProgram(unsigned int program);
extern void glAttachShader(unsigned int program, unsigned int shader);
extern void glLinkProgram(unsigned int program);
extern void glGetProgramiv(unsigned int program, unsigned int pname, int *params);
extern void glGetProgramInfoLog(unsigned int program, int maxLength, int *length, unsigned char *infoLog);
extern void glUseProgram(unsigned int program);
extern void glUniformBlockBinding(unsigned int program, unsigned int uniformBlockIndex, unsigned int uniformBlockBinding);
extern int glGetUniformLocation(unsigned int program, unsigned char *name);
extern void glUniform1i(int location, int v0);
extern void glUniform1f(int location, float v0);
extern void glUniform2f(int location, float v0, float v1);
extern void glUniform3f(int location, float v0, float v1, float v2);
extern void glUniform4f(int location, float v0, float v1, float v2, float v3);
extern void glUniformMatrix4fv(int location, int count, unsigned char transpose, float *value);
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
extern void glGenFramebuffers(int n, unsigned int *ids);
extern void glDeleteFramebuffers(int n, unsigned int *framebuffers);
extern void glBindFramebuffer(unsigned int target, unsigned int framebuffer);
extern void glFramebufferTexture2D(unsigned int target, unsigned int attachment, unsigned int textarget, unsigned int texture, int level);
extern void glFramebufferRenderbuffer(unsigned int target, unsigned int attachment, unsigned int renderbuffertarget, unsigned int renderbuffer);
extern void glDrawBuffers(int n, unsigned int *bufs);
extern unsigned int glCheckFramebufferStatus(unsigned int target);
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
extern void glGenRenderbuffers(int n, unsigned int *renderbuffers);
extern void glDeleteRenderbuffers(int n, unsigned int *renderbuffers);
extern void glBindRenderbuffer(unsigned int target, unsigned int renderbuffer);
extern void glRenderbufferStorage(unsigned int target, unsigned int internalformat, int width, int height);
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
extern void glGenSamplers(int n, unsigned int *samplers);
extern void glBindSampler(unsigned int unit, unsigned int sampler);
extern void glSamplerParameteri(unsigned int sampler, unsigned int pname, int param);
extern void glDeleteSamplers(int n, unsigned int *samplers);
#endif

#ifndef GL_NO_ERROR
#define GL_NO_ERROR 0
#endif
#ifndef GL_INVALID_ENUM
#define GL_INVALID_ENUM 0x0500
#endif
#ifndef GL_INVALID_VALUE
#define GL_INVALID_VALUE 0x0501
#endif
#ifndef GL_INVALID_OPERATION
#define GL_INVALID_OPERATION 0x0502
#endif
#ifndef GL_OUT_OF_MEMORY
#define GL_OUT_OF_MEMORY 0x0505
#endif
#ifndef GL_INVALID_FRAMEBUFFER_OPERATION
#define GL_INVALID_FRAMEBUFFER_OPERATION 0x0506
#endif
#ifndef GL_TRUE
#define GL_TRUE 1
#endif
#ifndef GL_FALSE
#define GL_FALSE 0
#endif

#ifndef GL_POINTS
#define GL_POINTS 0x0000
#endif
#ifndef GL_LINES
#define GL_LINES 0x0001
#endif
#ifndef GL_LINE_STRIP
#define GL_LINE_STRIP 0x0003
#endif
#ifndef GL_TRIANGLES
#define GL_TRIANGLES 0x0004
#endif
#ifndef GL_TRIANGLE_STRIP
#define GL_TRIANGLE_STRIP 0x0005
#endif

#ifndef GL_ONE
#define GL_ONE 1
#endif
#ifndef GL_ONE_MINUS_SRC_ALPHA
#define GL_ONE_MINUS_SRC_ALPHA 0x0303
#endif
#ifndef GL_BLEND
#define GL_BLEND 0x0BE2
#endif
#ifndef GL_VIEWPORT
#define GL_VIEWPORT 0x0BA2
#endif
#ifndef GL_EXTENSIONS
#define GL_EXTENSIONS 0x1F03
#endif
#ifndef GL_COLOR_BUFFER_BIT
#define GL_COLOR_BUFFER_BIT 0x00004000
#endif

#ifndef GL_UNSIGNED_BYTE
#define GL_UNSIGNED_BYTE 0x1401
#endif
#ifndef GL_BYTE
#define GL_BYTE 0x1400
#endif
#ifndef GL_SHORT
#define GL_SHORT 0x1402
#endif
#ifndef GL_UNSIGNED_SHORT
#define GL_UNSIGNED_SHORT 0x1403
#endif
#ifndef GL_INT
#define GL_INT 0x1404
#endif
#ifndef GL_UNSIGNED_INT
#define GL_UNSIGNED_INT 0x1405
#endif
#ifndef GL_FLOAT
#define GL_FLOAT 0x1406
#endif
#ifndef GL_DOUBLE
#define GL_DOUBLE 0x140A
#endif
#ifndef GL_HALF_FLOAT
#define GL_HALF_FLOAT 0x140B
#endif
#ifndef GL_RED
#define GL_RED 0x1903
#endif
#ifndef GL_RGB
#define GL_RGB 0x1907
#endif
#ifndef GL_RGBA
#define GL_RGBA 0x1908
#endif
#ifndef GL_BGRA
#define GL_BGRA 0x80E1
#endif

#ifndef GL_NEAREST
#define GL_NEAREST 0x2600
#endif
#ifndef GL_LINEAR
#define GL_LINEAR 0x2601
#endif
#ifndef GL_NEAREST_MIPMAP_NEAREST
#define GL_NEAREST_MIPMAP_NEAREST 0x2700
#endif
#ifndef GL_LINEAR_MIPMAP_NEAREST
#define GL_LINEAR_MIPMAP_NEAREST 0x2701
#endif
#ifndef GL_NEAREST_MIPMAP_LINEAR
#define GL_NEAREST_MIPMAP_LINEAR 0x2702
#endif
#ifndef GL_LINEAR_MIPMAP_LINEAR
#define GL_LINEAR_MIPMAP_LINEAR 0x2703
#endif
#ifndef GL_REPEAT
#define GL_REPEAT 0x2901
#endif

#ifndef GL_TEXTURE_1D
#define GL_TEXTURE_1D 0x0DE0
#endif
#ifndef GL_TEXTURE_2D
#define GL_TEXTURE_2D 0x0DE1
#endif
#ifndef GL_TEXTURE_WRAP_S
#define GL_TEXTURE_WRAP_S 0x2802
#endif
#ifndef GL_TEXTURE_WRAP_T
#define GL_TEXTURE_WRAP_T 0x2803
#endif
#ifndef GL_TEXTURE_MAG_FILTER
#define GL_TEXTURE_MAG_FILTER 0x2800
#endif
#ifndef GL_TEXTURE_MIN_FILTER
#define GL_TEXTURE_MIN_FILTER 0x2801
#endif

#ifndef GL_MAJOR_VERSION
#define GL_MAJOR_VERSION 0x821B
#endif
#ifndef GL_MINOR_VERSION
#define GL_MINOR_VERSION 0x821C
#endif
#ifndef GL_NUM_EXTENSIONS
#define GL_NUM_EXTENSIONS 0x821D
#endif
#ifndef GL_DEPTH_STENCIL_ATTACHMENT
#define GL_DEPTH_STENCIL_ATTACHMENT 0x821A
#endif
#ifndef GL_FRAMEBUFFER_UNDEFINED
#define GL_FRAMEBUFFER_UNDEFINED 0x8219
#endif

#ifndef GL_TEXTURE_3D
#define GL_TEXTURE_3D 0x806F
#endif
#ifndef GL_TEXTURE_WRAP_R
#define GL_TEXTURE_WRAP_R 0x8072
#endif
#ifndef GL_CLAMP_TO_BORDER
#define GL_CLAMP_TO_BORDER 0x812D
#endif
#ifndef GL_CLAMP_TO_EDGE
#define GL_CLAMP_TO_EDGE 0x812F
#endif
#ifndef GL_TEXTURE_MIN_LOD
#define GL_TEXTURE_MIN_LOD 0x813A
#endif
#ifndef GL_TEXTURE_MAX_LOD
#define GL_TEXTURE_MAX_LOD 0x813B
#endif
#ifndef GL_TEXTURE_BASE_LEVEL
#define GL_TEXTURE_BASE_LEVEL 0x813C
#endif
#ifndef GL_TEXTURE_MAX_LEVEL
#define GL_TEXTURE_MAX_LEVEL 0x813D
#endif
#ifndef GL_TEXTURE_LOD_BIAS
#define GL_TEXTURE_LOD_BIAS 0x8501
#endif
#ifndef GL_TEXTURE_CUBE_MAP
#define GL_TEXTURE_CUBE_MAP 0x8513
#endif
#ifndef GL_MIRRORED_REPEAT
#define GL_MIRRORED_REPEAT 0x8370
#endif
#ifndef GL_TEXTURE0
#define GL_TEXTURE0 0x84C0
#endif

#ifndef GL_ARRAY_BUFFER
#define GL_ARRAY_BUFFER 0x8892
#endif
#ifndef GL_ELEMENT_ARRAY_BUFFER
#define GL_ELEMENT_ARRAY_BUFFER 0x8893
#endif
#ifndef GL_STREAM_DRAW
#define GL_STREAM_DRAW 0x88E0
#endif
#ifndef GL_STREAM_READ
#define GL_STREAM_READ 0x88E1
#endif
#ifndef GL_STREAM_COPY
#define GL_STREAM_COPY 0x88E2
#endif
#ifndef GL_STATIC_DRAW
#define GL_STATIC_DRAW 0x88E4
#endif
#ifndef GL_STATIC_READ
#define GL_STATIC_READ 0x88E5
#endif
#ifndef GL_STATIC_COPY
#define GL_STATIC_COPY 0x88E6
#endif
#ifndef GL_DYNAMIC_DRAW
#define GL_DYNAMIC_DRAW 0x88E8
#endif
#ifndef GL_DYNAMIC_READ
#define GL_DYNAMIC_READ 0x88E9
#endif
#ifndef GL_DYNAMIC_COPY
#define GL_DYNAMIC_COPY 0x88EA
#endif
#ifndef GL_FRAGMENT_SHADER
#define GL_FRAGMENT_SHADER 0x8B30
#endif
#ifndef GL_VERTEX_SHADER
#define GL_VERTEX_SHADER 0x8B31
#endif
#ifndef GL_COMPILE_STATUS
#define GL_COMPILE_STATUS 0x8B81
#endif
#ifndef GL_LINK_STATUS
#define GL_LINK_STATUS 0x8B82
#endif
#ifndef GL_TEXTURE_RECTANGLE
#define GL_TEXTURE_RECTANGLE 0x84F5
#endif
#ifndef GL_TEXTURE_COMPARE_MODE
#define GL_TEXTURE_COMPARE_MODE 0x884C
#endif
#ifndef GL_TEXTURE_COMPARE_FUNC
#define GL_TEXTURE_COMPARE_FUNC 0x884D
#endif

#ifndef GL_RGB8
#define GL_RGB8 0x8051
#endif
#ifndef GL_RGBA8
#define GL_RGBA8 0x8058
#endif
#ifndef GL_SRGB8
#define GL_SRGB8 0x8C41
#endif
#ifndef GL_TEXTURE_1D_ARRAY
#define GL_TEXTURE_1D_ARRAY 0x8C18
#endif
#ifndef GL_TEXTURE_2D_ARRAY
#define GL_TEXTURE_2D_ARRAY 0x8C1A
#endif
#ifndef GL_TEXTURE_BUFFER
#define GL_TEXTURE_BUFFER 0x8C2A
#endif
#ifndef GL_FRAMEBUFFER_INCOMPLETE_DRAW_BUFFER
#define GL_FRAMEBUFFER_INCOMPLETE_DRAW_BUFFER 0x8CDB
#endif
#ifndef GL_FRAMEBUFFER_INCOMPLETE_READ_BUFFER
#define GL_FRAMEBUFFER_INCOMPLETE_READ_BUFFER 0x8CDC
#endif
#ifndef GL_FRAMEBUFFER_BINDING
#define GL_FRAMEBUFFER_BINDING 0x8CA6
#endif
#ifndef GL_RENDERBUFFER_BINDING
#define GL_RENDERBUFFER_BINDING 0x8CA7
#endif
#ifndef GL_READ_FRAMEBUFFER
#define GL_READ_FRAMEBUFFER 0x8CA8
#endif
#ifndef GL_DRAW_FRAMEBUFFER
#define GL_DRAW_FRAMEBUFFER 0x8CA9
#endif
#ifndef GL_COLOR_ATTACHMENT0
#define GL_COLOR_ATTACHMENT0 0x8CE0
#endif
#ifndef GL_FRAMEBUFFER_COMPLETE
#define GL_FRAMEBUFFER_COMPLETE 0x8CD5
#endif
#ifndef GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT
#define GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT 0x8CD6
#endif
#ifndef GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT
#define GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT 0x8CD7
#endif
#ifndef GL_FRAMEBUFFER_UNSUPPORTED
#define GL_FRAMEBUFFER_UNSUPPORTED 0x8CDD
#endif
#ifndef GL_FRAMEBUFFER_SRGB
#define GL_FRAMEBUFFER_SRGB 0x8DB9
#endif
#ifndef GL_SRGB8_ALPHA8
#define GL_SRGB8_ALPHA8 0x8C43
#endif

#ifndef GL_TEXTURE_SWIZZLE_R
#define GL_TEXTURE_SWIZZLE_R 0x8E42
#endif
#ifndef GL_TEXTURE_SWIZZLE_G
#define GL_TEXTURE_SWIZZLE_G 0x8E43
#endif
#ifndef GL_TEXTURE_SWIZZLE_B
#define GL_TEXTURE_SWIZZLE_B 0x8E44
#endif
#ifndef GL_TEXTURE_SWIZZLE_A
#define GL_TEXTURE_SWIZZLE_A 0x8E45
#endif

#ifndef GL_DEPTH_ATTACHMENT
#define GL_DEPTH_ATTACHMENT 0x8D00
#endif
#ifndef GL_STENCIL_ATTACHMENT
#define GL_STENCIL_ATTACHMENT 0x8D20
#endif
#ifndef GL_FRAMEBUFFER
#define GL_FRAMEBUFFER 0x8D40
#endif
#ifndef GL_RENDERBUFFER
#define GL_RENDERBUFFER 0x8D41
#endif
#ifndef GL_FRAMEBUFFER_INCOMPLETE_MULTISAMPLE
#define GL_FRAMEBUFFER_INCOMPLETE_MULTISAMPLE 0x8D56
#endif
#ifndef GL_FRAMEBUFFER_INCOMPLETE_LAYER_TARGETS
#define GL_FRAMEBUFFER_INCOMPLETE_LAYER_TARGETS 0x8DA8
#endif
#ifndef GL_DEBUG_OUTPUT
#define GL_DEBUG_OUTPUT 0x92E0
#endif
#ifndef GL_DEBUG_SOURCE_API
#define GL_DEBUG_SOURCE_API 0x8246
#define GL_DEBUG_SOURCE_WINDOW_SYSTEM 0x8247
#define GL_DEBUG_SOURCE_SHADER_COMPILER 0x8248
#define GL_DEBUG_SOURCE_THIRD_PARTY 0x8249
#define GL_DEBUG_SOURCE_APPLICATION 0x824A
#define GL_DEBUG_SOURCE_OTHER 0x824B
#endif
#ifndef GL_DEBUG_TYPE_ERROR
#define GL_DEBUG_TYPE_ERROR 0x824C
#define GL_DEBUG_TYPE_DEPRECATED_BEHAVIOR 0x824D
#define GL_DEBUG_TYPE_UNDEFINED_BEHAVIOR 0x824E
#define GL_DEBUG_TYPE_PORTABILITY 0x824F
#define GL_DEBUG_TYPE_PERFORMANCE 0x8250
#define GL_DEBUG_TYPE_OTHER 0x8251
#define GL_DEBUG_TYPE_MARKER 0x8268
#define GL_DEBUG_TYPE_PUSH_GROUP 0x8269
#define GL_DEBUG_TYPE_POP_GROUP 0x826A
#endif
#ifndef GL_DEBUG_SEVERITY_HIGH
#define GL_DEBUG_SEVERITY_HIGH 0x9146
#define GL_DEBUG_SEVERITY_MEDIUM 0x9147
#define GL_DEBUG_SEVERITY_LOW 0x9148
#define GL_DEBUG_SEVERITY_NOTIFICATION 0x826B
#endif
#ifndef GL_UNIFORM_BUFFER
#define GL_UNIFORM_BUFFER 0x8A11
#endif
#ifndef GL_SHADER_STORAGE_BUFFER
#define GL_SHADER_STORAGE_BUFFER 0x90D2
#endif

#if defined(_MSC_VER)
#define WITTY_GL_THREAD_LOCAL __declspec(thread)
#else
#define WITTY_GL_THREAD_LOCAL _Thread_local
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
static WITTY_GL_THREAD_LOCAL GladGLContext witty_gl_context;
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
static int witty_gl_load(void *get_proc_address) {
	if (get_proc_address != 0) {
		return gladLoadGLContext(&witty_gl_context, (GLADloadfunc)get_proc_address);
	}
	return gladLoaderLoadGLContext(&witty_gl_context);
}
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
static void witty_gl_unload(void) {
	gladLoaderUnloadGLContext(&witty_gl_context);
	memset(&witty_gl_context, 0, sizeof(witty_gl_context));
}
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
static int witty_glVertexBindingDivisor(unsigned int bindingindex, unsigned int divisor) {
	if (witty_gl_context.VertexBindingDivisor == 0) {
		return 0;
	}
	witty_gl_context.VertexBindingDivisor(bindingindex, divisor);
	return 1;
}
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
static int witty_glVertexAttribBinding(unsigned int attribindex, unsigned int bindingindex) {
	if (witty_gl_context.VertexAttribBinding == 0) {
		return 0;
	}
	witty_gl_context.VertexAttribBinding(attribindex, bindingindex);
	return 1;
}
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
static int witty_glVertexAttribFormat(
	unsigned int attribindex,
	int size,
	unsigned int type,
	unsigned char normalized,
	unsigned int relativeoffset
) {
	if (witty_gl_context.VertexAttribFormat == 0) {
		return 0;
	}
	witty_gl_context.VertexAttribFormat(attribindex, size, type, normalized, relativeoffset);
	return 1;
}
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
static int witty_glVertexAttribIFormat(
	unsigned int attribindex,
	int size,
	unsigned int type,
	unsigned int relativeoffset
) {
	if (witty_gl_context.VertexAttribIFormat == 0) {
		return 0;
	}
	witty_gl_context.VertexAttribIFormat(attribindex, size, type, relativeoffset);
	return 1;
}
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
static int witty_glVertexAttribLFormat(
	unsigned int attribindex,
	int size,
	unsigned int type,
	unsigned int relativeoffset
) {
	if (witty_gl_context.VertexAttribLFormat == 0) {
		return 0;
	}
	witty_gl_context.VertexAttribLFormat(attribindex, size, type, relativeoffset);
	return 1;
}
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
static int witty_glBindVertexBuffer(
	unsigned int bindingindex,
	unsigned int buffer,
	intptr_t offset,
	int stride
) {
	if (witty_gl_context.BindVertexBuffer == 0) {
		return 0;
	}
	witty_gl_context.BindVertexBuffer(bindingindex, buffer, offset, stride);
	return 1;
}
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
static int witty_glBlitFramebuffer(
	int src_x0,
	int src_y0,
	int src_x1,
	int src_y1,
	int dst_x0,
	int dst_y0,
	int dst_x1,
	int dst_y1,
	unsigned int mask,
	unsigned int filter
) {
	if (witty_gl_context.BlitFramebuffer == 0) {
		return 0;
	}
	witty_gl_context.BlitFramebuffer(src_x0, src_y0, src_x1, src_y1, dst_x0, dst_y0, dst_x1, dst_y1, mask, filter);
	return 1;
}
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
typedef void (*witty_gl_debug_callback)(
	unsigned int,
	unsigned int,
	unsigned int,
	unsigned int,
	int,
	const unsigned char *,
	const void *
);
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
static int witty_glDebugMessageCallback(void *callback, void *user_param) {
	if (witty_gl_context.DebugMessageCallback == 0) {
		return 0;
	}
	witty_gl_context.DebugMessageCallback((GLDEBUGPROC)callback, user_param);
	return 1;
}
#endif

#ifdef _VTEST
#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
static const GLubyte *witty_gl_test_get_string(GLenum name) {
	if (name == GL_VERSION) {
		return (const GLubyte *)"4.3 Witty Glad test";
	}
	return (const GLubyte *)"";
}
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
static void witty_gl_test_get_integerv(GLenum name, GLint *value) {
	(void)name;
	if (value != 0) {
		*value = 0;
	}
}
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
static GLenum witty_gl_test_get_error(void) {
	return GL_NO_ERROR;
}
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
static void witty_gl_test_noop(void) {
}
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
static GLADapiproc witty_gl_test_resolver(const char *name) {
	if (strcmp(name, "glGetString") == 0) {
		return (GLADapiproc)witty_gl_test_get_string;
	}
	if (strcmp(name, "glGetIntegerv") == 0) {
		return (GLADapiproc)witty_gl_test_get_integerv;
	}
	if (strcmp(name, "glGetError") == 0) {
		return (GLADapiproc)witty_gl_test_get_error;
	}
	return (GLADapiproc)witty_gl_test_noop;
}
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
static void *witty_gl_test_resolver_pointer(void) {
	return (void *)witty_gl_test_resolver;
}
#endif

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
static int witty_gl_test_context_loaded(void) {
	return witty_gl_context.GetString != 0 &&
		witty_gl_context.GetIntegerv != 0 &&
		witty_gl_context.GetError != 0;
}
#endif
#endif

/*
 * The pinned Glad build uses its explicit context instead of defining global
 * gl* symbols. These macros preserve the C spellings used by V while routing
 * every operation through the same thread-local context as Ghostty.
 */
#define glActiveTexture(...) witty_gl_context.ActiveTexture(__VA_ARGS__)
#define glAttachShader(...) witty_gl_context.AttachShader(__VA_ARGS__)
#define glBindBuffer(...) witty_gl_context.BindBuffer(__VA_ARGS__)
#define glBindBufferBase(...) witty_gl_context.BindBufferBase(__VA_ARGS__)
#define glBindFramebuffer(...) witty_gl_context.BindFramebuffer(__VA_ARGS__)
#define glBindRenderbuffer(...) witty_gl_context.BindRenderbuffer(__VA_ARGS__)
#define glBindSampler(...) witty_gl_context.BindSampler(__VA_ARGS__)
#define glBindTexture(...) witty_gl_context.BindTexture(__VA_ARGS__)
#define glBindVertexArray(...) witty_gl_context.BindVertexArray(__VA_ARGS__)
#define glBlendFunc(...) witty_gl_context.BlendFunc(__VA_ARGS__)
#define glBufferData(...) witty_gl_context.BufferData(__VA_ARGS__)
#define glBufferSubData(...) witty_gl_context.BufferSubData(__VA_ARGS__)
#define glCheckFramebufferStatus(...) witty_gl_context.CheckFramebufferStatus(__VA_ARGS__)
#define glClear(...) witty_gl_context.Clear(__VA_ARGS__)
#define glClearColor(...) witty_gl_context.ClearColor(__VA_ARGS__)
#define glCompileShader(...) witty_gl_context.CompileShader(__VA_ARGS__)
#define glCopyTexSubImage2D(...) witty_gl_context.CopyTexSubImage2D(__VA_ARGS__)
#define glCreateProgram(...) witty_gl_context.CreateProgram(__VA_ARGS__)
#define glCreateShader(...) witty_gl_context.CreateShader(__VA_ARGS__)
#define glDeleteBuffers(...) witty_gl_context.DeleteBuffers(__VA_ARGS__)
#define glDeleteFramebuffers(...) witty_gl_context.DeleteFramebuffers(__VA_ARGS__)
#define glDeleteProgram(...) witty_gl_context.DeleteProgram(__VA_ARGS__)
#define glDeleteRenderbuffers(...) witty_gl_context.DeleteRenderbuffers(__VA_ARGS__)
#define glDeleteSamplers(...) witty_gl_context.DeleteSamplers(__VA_ARGS__)
#define glDeleteShader(...) witty_gl_context.DeleteShader(__VA_ARGS__)
#define glDeleteTextures(...) witty_gl_context.DeleteTextures(__VA_ARGS__)
#define glDeleteVertexArrays(...) witty_gl_context.DeleteVertexArrays(__VA_ARGS__)
#define glDisable(...) witty_gl_context.Disable(__VA_ARGS__)
#define glDrawArrays(...) witty_gl_context.DrawArrays(__VA_ARGS__)
#define glDrawArraysInstanced(...) witty_gl_context.DrawArraysInstanced(__VA_ARGS__)
#define glDrawBuffers(...) witty_gl_context.DrawBuffers(__VA_ARGS__)
#define glDrawElements(...) witty_gl_context.DrawElements(__VA_ARGS__)
#define glDrawElementsInstanced(...) witty_gl_context.DrawElementsInstanced(__VA_ARGS__)
#define glEnable(...) witty_gl_context.Enable(__VA_ARGS__)
#define glEnableVertexAttribArray(...) witty_gl_context.EnableVertexAttribArray(__VA_ARGS__)
#define glFinish(...) witty_gl_context.Finish(__VA_ARGS__)
#define glFlush(...) witty_gl_context.Flush(__VA_ARGS__)
#define glFramebufferRenderbuffer(...) witty_gl_context.FramebufferRenderbuffer(__VA_ARGS__)
#define glFramebufferTexture2D(...) witty_gl_context.FramebufferTexture2D(__VA_ARGS__)
#define glFrontFace(...) witty_gl_context.FrontFace(__VA_ARGS__)
#define glGenBuffers(...) witty_gl_context.GenBuffers(__VA_ARGS__)
#define glGenFramebuffers(...) witty_gl_context.GenFramebuffers(__VA_ARGS__)
#define glGenRenderbuffers(...) witty_gl_context.GenRenderbuffers(__VA_ARGS__)
#define glGenSamplers(...) witty_gl_context.GenSamplers(__VA_ARGS__)
#define glGenTextures(...) witty_gl_context.GenTextures(__VA_ARGS__)
#define glGenVertexArrays(...) witty_gl_context.GenVertexArrays(__VA_ARGS__)
#define glGenerateMipmap(...) witty_gl_context.GenerateMipmap(__VA_ARGS__)
#define glGetError(...) witty_gl_context.GetError(__VA_ARGS__)
#define glGetIntegerv(...) witty_gl_context.GetIntegerv(__VA_ARGS__)
#define glGetProgramInfoLog(...) witty_gl_context.GetProgramInfoLog(__VA_ARGS__)
#define glGetProgramiv(...) witty_gl_context.GetProgramiv(__VA_ARGS__)
#define glGetShaderInfoLog(...) witty_gl_context.GetShaderInfoLog(__VA_ARGS__)
#define glGetShaderiv(...) witty_gl_context.GetShaderiv(__VA_ARGS__)
#define glGetStringi(...) witty_gl_context.GetStringi(__VA_ARGS__)
#define glGetUniformLocation(...) witty_gl_context.GetUniformLocation(__VA_ARGS__)
#define glLinkProgram(...) witty_gl_context.LinkProgram(__VA_ARGS__)
#define glPixelStorei(...) witty_gl_context.PixelStorei(__VA_ARGS__)
#define glRenderbufferStorage(...) witty_gl_context.RenderbufferStorage(__VA_ARGS__)
#define glSamplerParameteri(...) witty_gl_context.SamplerParameteri(__VA_ARGS__)
#define glShaderSource(...) witty_gl_context.ShaderSource(__VA_ARGS__)
#define glTexImage2D(...) witty_gl_context.TexImage2D(__VA_ARGS__)
#define glTexParameteri(...) witty_gl_context.TexParameteri(__VA_ARGS__)
#define glTexSubImage2D(...) witty_gl_context.TexSubImage2D(__VA_ARGS__)
#define glUniform1f(...) witty_gl_context.Uniform1f(__VA_ARGS__)
#define glUniform1i(...) witty_gl_context.Uniform1i(__VA_ARGS__)
#define glUniform2f(...) witty_gl_context.Uniform2f(__VA_ARGS__)
#define glUniform3f(...) witty_gl_context.Uniform3f(__VA_ARGS__)
#define glUniform4f(...) witty_gl_context.Uniform4f(__VA_ARGS__)
#define glUniformBlockBinding(...) witty_gl_context.UniformBlockBinding(__VA_ARGS__)
#define glUniformMatrix4fv(...) witty_gl_context.UniformMatrix4fv(__VA_ARGS__)
#define glUseProgram(...) witty_gl_context.UseProgram(__VA_ARGS__)
#define glVertexAttribDivisor(...) witty_gl_context.VertexAttribDivisor(__VA_ARGS__)
#define glVertexAttribIPointer(...) witty_gl_context.VertexAttribIPointer(__VA_ARGS__)
#define glVertexAttribPointer(...) witty_gl_context.VertexAttribPointer(__VA_ARGS__)
#define glViewport(...) witty_gl_context.Viewport(__VA_ARGS__)

#endif
