#ifndef WITTY_OPENGL_CONSTANTS_H
#define WITTY_OPENGL_CONSTANTS_H

#include <dlfcn.h>
#include <stdint.h>

/*
 * Keep this header independent from platform GL headers. opengl.v declares
 * the core GL entry points itself; including platform GL headers here gives
 * the C compiler two declarations for the same function and breaks builds on
 * macOS. The OpenGL 4.3 entry points are resolved dynamically so this module
 * can still compile on platforms whose link-time GL library lacks them.
 */

extern unsigned int glGetError(void);
extern void glGetIntegerv(unsigned int pname, int *data);
extern const unsigned char *glGetStringi(unsigned int name, unsigned int index);

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

extern void glActiveTexture(unsigned int texture);
extern void glGenTextures(int n, unsigned int *textures);
extern void glBindTexture(unsigned int target, unsigned int texture);
extern void glDeleteTextures(int n, unsigned int *textures);
extern void glGenerateMipmap(unsigned int target);
extern void glTexParameteri(unsigned int target, unsigned int pname, int param);
extern void glTexImage2D(unsigned int target, int level, int internalformat, int width, int height, int border, unsigned int format, unsigned int type, void *pixels);
extern void glTexSubImage2D(unsigned int target, int level, int xoffset, int yoffset, int width, int height, unsigned int format, unsigned int type, void *pixels);
extern void glCopyTexSubImage2D(unsigned int target, int level, int xoffset, int yoffset, int x, int y, int width, int height);

extern void glGenVertexArrays(int n, unsigned int *arrays);
extern void glBindVertexArray(unsigned int array);
extern void glDeleteVertexArrays(int n, unsigned int *arrays);

extern unsigned int glCreateShader(unsigned int type);
extern void glShaderSource(unsigned int shader, int count, unsigned char **string, int *length);
extern void glCompileShader(unsigned int shader);
extern void glGetShaderiv(unsigned int shader, unsigned int pname, int *params);
extern void glGetShaderInfoLog(unsigned int shader, int maxLength, int *length, unsigned char *infoLog);
extern void glDeleteShader(unsigned int shader);

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

extern void glGenFramebuffers(int n, unsigned int *ids);
extern void glDeleteFramebuffers(int n, unsigned int *framebuffers);
extern void glBindFramebuffer(unsigned int target, unsigned int framebuffer);
extern void glFramebufferTexture2D(unsigned int target, unsigned int attachment, unsigned int textarget, unsigned int texture, int level);
extern void glFramebufferRenderbuffer(unsigned int target, unsigned int attachment, unsigned int renderbuffertarget, unsigned int renderbuffer);
extern void glDrawBuffers(int n, unsigned int *bufs);
extern unsigned int glCheckFramebufferStatus(unsigned int target);

extern void glGenRenderbuffers(int n, unsigned int *renderbuffers);
extern void glDeleteRenderbuffers(int n, unsigned int *renderbuffers);
extern void glBindRenderbuffer(unsigned int target, unsigned int renderbuffer);
extern void glRenderbufferStorage(unsigned int target, unsigned int internalformat, int width, int height);

extern void glGenSamplers(int n, unsigned int *samplers);
extern void glBindSampler(unsigned int unit, unsigned int sampler);
extern void glSamplerParameteri(unsigned int sampler, unsigned int pname, int param);
extern void glDeleteSamplers(int n, unsigned int *samplers);

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
#ifndef GL_UNIFORM_BUFFER
#define GL_UNIFORM_BUFFER 0x8A11
#endif
#ifndef GL_SHADER_STORAGE_BUFFER
#define GL_SHADER_STORAGE_BUFFER 0x90D2
#endif

#ifndef __APPLE__
typedef void (*witty_gl_proc)(void);
typedef witty_gl_proc (*witty_glx_get_proc_address_arb_fn)(const unsigned char *);
#endif

static void *witty_gl_get_proc(const char *name) {
#ifndef __APPLE__
	static witty_glx_get_proc_address_arb_fn glx_get_proc = 0;
	if (glx_get_proc == 0) {
		glx_get_proc = (witty_glx_get_proc_address_arb_fn)dlsym(RTLD_DEFAULT, "glXGetProcAddressARB");
	}
	if (glx_get_proc != 0) {
		void *proc = (void *)glx_get_proc((const unsigned char *)name);
		if (proc != 0) {
			return proc;
		}
	}
#endif
	return dlsym(RTLD_DEFAULT, name);
}

static int witty_glVertexBindingDivisor(unsigned int bindingindex, unsigned int divisor) {
	typedef void (*proc_fn)(unsigned int, unsigned int);
	static proc_fn proc = 0;
	if (proc == 0) {
		proc = (proc_fn)witty_gl_get_proc("glVertexBindingDivisor");
	}
	if (proc == 0) {
		return 0;
	}
	proc(bindingindex, divisor);
	return 1;
}

static int witty_glVertexAttribBinding(unsigned int attribindex, unsigned int bindingindex) {
	typedef void (*proc_fn)(unsigned int, unsigned int);
	static proc_fn proc = 0;
	if (proc == 0) {
		proc = (proc_fn)witty_gl_get_proc("glVertexAttribBinding");
	}
	if (proc == 0) {
		return 0;
	}
	proc(attribindex, bindingindex);
	return 1;
}

static int witty_glVertexAttribFormat(
	unsigned int attribindex,
	int size,
	unsigned int type,
	unsigned char normalized,
	unsigned int relativeoffset
) {
	typedef void (*proc_fn)(unsigned int, int, unsigned int, unsigned char, unsigned int);
	static proc_fn proc = 0;
	if (proc == 0) {
		proc = (proc_fn)witty_gl_get_proc("glVertexAttribFormat");
	}
	if (proc == 0) {
		return 0;
	}
	proc(attribindex, size, type, normalized, relativeoffset);
	return 1;
}

static int witty_glVertexAttribIFormat(
	unsigned int attribindex,
	int size,
	unsigned int type,
	unsigned int relativeoffset
) {
	typedef void (*proc_fn)(unsigned int, int, unsigned int, unsigned int);
	static proc_fn proc = 0;
	if (proc == 0) {
		proc = (proc_fn)witty_gl_get_proc("glVertexAttribIFormat");
	}
	if (proc == 0) {
		return 0;
	}
	proc(attribindex, size, type, relativeoffset);
	return 1;
}

static int witty_glVertexAttribLFormat(
	unsigned int attribindex,
	int size,
	unsigned int type,
	unsigned int relativeoffset
) {
	typedef void (*proc_fn)(unsigned int, int, unsigned int, unsigned int);
	static proc_fn proc = 0;
	if (proc == 0) {
		proc = (proc_fn)witty_gl_get_proc("glVertexAttribLFormat");
	}
	if (proc == 0) {
		return 0;
	}
	proc(attribindex, size, type, relativeoffset);
	return 1;
}

static int witty_glBindVertexBuffer(
	unsigned int bindingindex,
	unsigned int buffer,
	intptr_t offset,
	int stride
) {
	typedef void (*proc_fn)(unsigned int, unsigned int, intptr_t, int);
	static proc_fn proc = 0;
	if (proc == 0) {
		proc = (proc_fn)witty_gl_get_proc("glBindVertexBuffer");
	}
	if (proc == 0) {
		return 0;
	}
	proc(bindingindex, buffer, offset, stride);
	return 1;
}

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
	typedef void (*proc_fn)(int, int, int, int, int, int, int, int, unsigned int, unsigned int);
	static proc_fn proc = 0;
	if (proc == 0) {
		proc = (proc_fn)witty_gl_get_proc("glBlitFramebuffer");
	}
	if (proc == 0) {
		return 0;
	}
	proc(src_x0, src_y0, src_x1, src_y1, dst_x0, dst_y0, dst_x1, dst_y1, mask, filter);
	return 1;
}

#endif
