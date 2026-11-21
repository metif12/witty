module xev

import log

// src/watcher/process.zig ProcessIocp, libxev 34fa508.
fn C.GetCurrentProcess() voidptr
fn C.DuplicateHandle(source_process voidptr, source voidptr, target_process voidptr, target &voidptr, access u32, inherit int, options u32) bool
fn C.CreateJobObjectA(attributes voidptr, name &char) voidptr
fn C.AssignProcessToJobObject(job voidptr, process voidptr) bool
fn C.GetExitCodeProcess(process voidptr, code &u32) bool
fn C.GetProcessId(process voidptr) u32

pub type IocpProcessCallback = fn (ud voidptr, l &IocpLoop, c &IocpCompletion, r ?ErrorKind, exit_code u32) CallbackAction

pub struct IocpProcess {
pub mut:
	job     voidptr
	process voidptr
}

pub fn IocpProcess.init(process voidptr) !IocpProcess {
	current := C.GetCurrentProcess()
	mut dup := voidptr(unsafe { nil })
	if !C.DuplicateHandle(current, process, current, &dup, 0, 0, 2) {
		return new_error(.unexpected)
	}
	job := C.CreateJobObjectA(unsafe { nil }, unsafe { nil })
	// The source wrapper branches on GetLastError, including ALREADY_EXISTS.
	code := C.GetLastError()
	if code != 0 {
		return new_error(if code == 183 { ErrorKind.already_exists } else { ErrorKind.unexpected })
	}
	if !C.AssignProcessToJobObject(job, dup) {
		C.CloseHandle(job)
		return new_error(.unexpected)
	}
	return IocpProcess{ job: job, process: dup }
}

pub fn (mut self IocpProcess) deinit() {
	C.CloseHandle(self.job)
	C.CloseHandle(self.process)
}

pub fn (self &IocpProcess) wait(mut loop IocpLoop, c_ &IocpCompletion, userdata voidptr, cb IocpProcessCallback) {
	mut c := unsafe { c_ }
	unsafe {
		*c = IocpCompletion{
			op:       IocpJobObjectOp{ job: self.job, userdata: self.process }
			userdata: userdata
			callback: fn [cb] (ud voidptr, l &IocpLoop, c &IocpCompletion, r IocpResult) CallbackAction {
				result := r as IocpJobObjectResult
				if err := result.err { return cb(ud, l, c, err, 0) }
				process := (c.op as IocpJobObjectOp).userdata
				match result.value {
					IocpJobObjectAssociated {
						mut code := u32(0)
						has_code := C.GetExitCodeProcess(process, &code)
						if !has_code {
							log.warn('unable to get exit code for process=${C.GetLastError()}')
						}
						// Preserve the source's STATUS_PENDING constant (0x103).
						if code == 0x103 { return .rearm }
						return cb(ud, l, c, none, code)
					}
					IocpJobObjectMessage {
						if result.value.type_ != 7 && result.value.type_ != 8 { return .rearm }
						pid := C.GetProcessId(process)
						if pid == 0 { return cb(ud, l, c, ErrorKind.unexpected, 0) }
						if result.value.value != uint(pid) { return .rearm }
						mut code := u32(0)
						has_code := C.GetExitCodeProcess(process, &code)
						if !has_code {
							log.warn('unable to get exit code for process=${C.GetLastError()}')
							return cb(ud, l, c, ErrorKind.unexpected, 0)
						}
						return cb(ud, l, c, none, code)
					}
				}
			}
		}
	}
	loop.add(c)
}
