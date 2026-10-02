module termio

import log

#flag windows -lntdll
#include "@VMODROOT/termio/exec_windows_path.h"

fn C.witty_exec_cwd_handle() voidptr
fn C.RtlGetFullPathName_U(path &u16, size u32, buffer &u16, part voidptr) u32
fn C.NtQueryAttributesFile(attributes &C.OBJECT_ATTRIBUTES, info &C.FILE_BASIC_INFORMATION) int

@[typedef]
struct C.UNICODE_STRING {
mut:
	Length        u16
	MaximumLength u16
	Buffer        &u16 = unsafe { nil }
}

@[typedef]
struct C.OBJECT_ATTRIBUTES {
mut:
	Length                   u32
	RootDirectory            voidptr
	ObjectName               &C.UNICODE_STRING = unsafe { nil }
	Attributes               u32
	SecurityDescriptor       voidptr
	SecurityQualityOfService voidptr
}

@[typedef]
struct C.FILE_BASIC_INFORMATION {
	CreationTime   i64
	LastAccessTime i64
	LastWriteTime  i64
	ChangeTime     i64
	FileAttributes u32
}

// This call site always supplies std.fs.cwd().fd, so source paths that resolve
// another directory HANDLE are inapplicable. RtlGetFullPathName_U resolves any
// excess parent components against the process cwd, exactly as the source.
fn windows_path_prefixed(path string) ![]u16 {
	mut wide := windows_path_wtf16(path)!
	prefix := [u16(92), u16(63), u16(63), u16(92)]
	mut output := []u16{len: 32768}
	kind := windows_path_namespace(wide)
	if kind == .nt || kind == .verbatim {
		for i, c in prefix { output[i] = c }
		for i in 4 .. wide.len { output[i] = wide[i] }
		return output[..wide.len + 1]
	}
	wide << 0
	if kind == .local_device || kind == .fake_verbatim {
		bytes := C.RtlGetFullPathName_U(wide.data, u32(32767 * 2), output.data, unsafe { nil })
		if bytes == 0 { return error('BadPathName') }
		if bytes / 2 > u32(32767) { return error('NameTooLong') }
		for i, c in prefix { output[i] = c }
		return output[..int(bytes / 2) + 1]
	}
	path_type := windows_path_type(wide[..wide.len - 1])
	if path_type == .relative {
		mut relative := wide[..wide.len - 1].clone()
		len := windows_path_normalize(mut relative) or { -1 }
		if len >= 0 {
			relative = relative[..len]
			relative << 0
			return relative
		}
	}
	for i, c in prefix { output[i] = c }
	if path_type == .root_local_device { return output[..5] }
	offset := if path_type == .unc_absolute { 6 } else { 4 }
	bytes := C.RtlGetFullPathName_U(wide.data, u32((32767 - offset) * 2), unsafe { &output[offset] }, unsafe { nil })
	if bytes == 0 { return error('BadPathName') }
	if bytes / 2 > u32(32767 - offset) { return error('NameTooLong') }
	if path_type == .unc_absolute {
		output[4] = u16(85)
		output[5] = u16(78)
		output[6] = u16(67)
	}
	return output[..offset + int(bytes / 2) + 1]
}

fn windows_path_access(path string) ! {
	wide := windows_path_prefixed(path)!
	if (wide.len == 2 && wide[0] == u16(46)) || (wide.len == 3 && wide[0] == u16(46) && wide[1] == u16(46)) {
		return
	}
	if (wide.len - 1) * 2 > 0xffff { return error('NameTooLong') }
	mut name := C.UNICODE_STRING{ Length: u16((wide.len - 1) * 2), MaximumLength: u16((wide.len - 1) * 2), Buffer: wide.data }
	absolute := (wide.len > 1 && windows_path_separator(wide[0])) || (wide.len >= 4 && wide[1] == u16(58) && windows_path_separator(wide[2]))
	mut root_directory := voidptr(unsafe { nil })
	if !absolute { root_directory = C.witty_exec_cwd_handle() }
	mut attr := C.OBJECT_ATTRIBUTES{
		Length:        u32(sizeof(C.OBJECT_ATTRIBUTES))
		RootDirectory: root_directory
		ObjectName:    &name
	}
	mut info := C.FILE_BASIC_INFORMATION{}
	rc := u32(C.NtQueryAttributesFile(&attr, &info))
	match rc {
		0 { return }
		0xc0000034, 0xc000003a { return error('FileNotFound') }
		0xc0000033, 0xc000000d, 0xc000003b { panic('unreachable') }
		0xc0000022 { return error('AccessDenied') }
		else { return error('Unexpected: ${rc}') }
	}
}

fn windows_cwd_access(path string) bool {
	windows_path_access(path) or {
		log.warn('cannot access cwd, ignoring: ${err}')
		return false
	}
	return true
}
