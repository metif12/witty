module gtk

import os

// cgroup_linux.v - Systemd cgroup single-instance management.
//
// Translated from ghostty/src/apprt/gtk/cgroup.zig, together with the cgroup
// filesystem helpers it depends on from ghostty/src/os/cgroup.zig
// (internal_os.cgroup.*).
//
// The purpose is to put the Ghostty process (and each surface) into its own
// systemd transient scope + cgroup v2 hierarchy so resource limits can be
// applied per-surface without affecting the main app.
//
// Two layers are translated here:
//   1. The cgroup v2 filesystem helpers (read/write under /sys/fs/cgroup and
//      /proc/<pid>/cgroup). In Zig these use std.fs; here we use V's `os`
//      module (os.read_file / os.write_file / os.mkdir_all).
//   2. The high-level `init` + `create_scope` logic, which creates the systemd
//      transient scope over D-Bus and configures the controllers/limits.
//
// The D-Bus scope creation (create_scope) builds a GVariant parameter tuple and
// calls StartTransientUnit on org.freedesktop.systemd1. There is no D-Bus
// binding module in witty yet, so the minimal GVariant/GDBusConnection C
// functions it needs are declared once in ipc_dbus_linux.v.

// --- Options --------------------------------------------------------------

// Options configures the resource limits applied to the surfaces cgroup.
// Mirrors `cgroup.Options`.
pub struct Options {
pub:
	// memory_high is the soft "high" memory limit in bytes, if set.
	memory_high ?u64
	// pids_max is the hard max number of pids, if set.
	pids_max ?u64
}

// --- Errors ---------------------------------------------------------------

// CgroupError enumerates failures from cgroup setup, mirroring the Zig error
// set used across cgroup.zig / os/cgroup.zig.
pub enum CgroupError {
	dbus_call_failed
	no_cgroup
	io_error
}

// --- D-Bus / GVariant bindings --------------------------------------------
//
// The core GVariant / GVariantBuilder / GDBusConnection types and functions
// (g_variant_type_*, g_variant_builder_*, g_dbus_connection_call_sync,
// g_variant_unref, etc.) are already declared in ipc_dbus_linux.v — reused
// here, NOT redeclared.

// --- cgroup v2 filesystem helpers -----------------------------------------
// Translated from ghostty/src/os/cgroup.zig (internal_os.cgroup.*).

// cgroup_current returns the path to the cgroup for the given pid, or none.
// Mirrors `os.cgroup.current`.
//
// It reads /proc/<pid>/cgroup whose first line looks like:
//   0::/user.slice/user-1000.slice/session-1.scope
// The cgroup path is the field after the last ':'.
pub fn cgroup_current(pid int) ?string {
	path := '/proc/${pid}/cgroup'
	contents := os.read_file(path) or { return none }

	// Find the last ':'.
	idx := contents.last_index_u8(`:`)
	if idx < 0 {
		return none
	}
	result := contents[idx + 1..].trim_right(' \r\n')
	return result
}

// cgroup_create creates a new cgroup. If `move` is set (>= 0), the given pid is
// moved into the created cgroup. Mirrors `os.cgroup.create`.
pub fn cgroup_create(cgroup string, child string, move int) ! {
	path := '/sys/fs/cgroup${cgroup}/${child}'
	os.mkdir_all(path)!

	if move >= 0 {
		pid_path := '/sys/fs/cgroup${cgroup}/${child}/cgroup.procs'
		os.write_file(pid_path, move.str())!
	}
}

// cgroup_remove removes a cgroup. This only succeeds if the cgroup is empty.
// The path must be '/'-prefixed. Mirrors `os.cgroup.remove`.
pub fn cgroup_remove(cgroup string) ! {
	if cgroup.len == 0 || cgroup[0] != `/` {
		return error('cgroup path must be non-empty and /-prefixed')
	}
	path := '/sys/fs/cgroup${cgroup}'
	// If it doesn't exist, that's fine - maybe it was already cleaned up.
	if !os.exists(path) {
		return
	}
	os.rmdir(path)!
}

// cgroup_move_into moves the given PID into the given cgroup. Mirrors
// `os.cgroup.moveInto`.
pub fn cgroup_move_into(cgroup string, pid int) ! {
	path := '/sys/fs/cgroup${cgroup}/cgroup.procs'
	os.write_file(path, pid.str())!
}

// cgroup_controllers returns the raw space-separated list of available
// controllers for the given ('/'-prefixed) cgroup. Mirrors
// `os.cgroup.controllers`.
pub fn cgroup_controllers(cgroup string) !string {
	path := '/sys/fs/cgroup${cgroup}/cgroup.controllers'
	contents := os.read_file(path)!
	return contents.trim_right(' \r\n')
}

// cgroup_configure_controllers writes `v` (a valid cgroup.subtree_control
// value) to the cgroup's cgroup.subtree_control. Mirrors
// `os.cgroup.configureControllers`.
pub fn cgroup_configure_controllers(cgroup string, v string) ! {
	if cgroup.len == 0 || cgroup[0] != `/` {
		return error('cgroup path must be /-prefixed')
	}
	path := '/sys/fs/cgroup${cgroup}/cgroup.subtree_control'
	os.write_file(path, v)!
}

// cgroup_configure_memory_high writes a memory.high (soft) limit in bytes.
// Mirrors `os.cgroup.configureLimit(.{ .memory_high = ... })`.
pub fn cgroup_configure_memory_high(cgroup string, size u64) ! {
	if cgroup.len == 0 || cgroup[0] != `/` {
		return error('cgroup path must be /-prefixed')
	}
	path := '/sys/fs/cgroup${cgroup}/memory.high'
	os.write_file(path, size.str())!
}

// cgroup_configure_pids_max writes a pids.max (hard) limit. Mirrors
// `os.cgroup.configureLimit(.{ .pids_max = ... })`.
pub fn cgroup_configure_pids_max(cgroup string, size u64) ! {
	if cgroup.len == 0 || cgroup[0] != `/` {
		return error('cgroup path must be /-prefixed')
	}
	path := '/sys/fs/cgroup${cgroup}/pids.max'
	os.write_file(path, size.str())!
}

// --- High-level init ------------------------------------------------------

// enable_controllers enables all cgroup controllers for the given cgroup.
// Mirrors `enableControllers` in cgroup.zig: it reads the available controllers
// (space-separated) and writes them back prefixed with '+'.
fn enable_controllers(cgroup string) ! {
	raw := cgroup_controllers(cgroup)!

	// Controllers are space-separated; build "+a +b +c".
	mut parts := []string{}
	for controller in raw.split(' ') {
		if controller.len == 0 {
			continue
		}
		parts << '+' + controller
	}
	cgroup_configure_controllers(cgroup, parts.join(' '))!
}

// init initializes the cgroup for the app. It creates the transient systemd
// scope, initializes the app/surfaces cgroups, configures them, and returns the
// cgroup path for the app. Mirrors `cgroup.init`.
//
// `dbus` is a gio.DBusConnection*.
pub fn cgroup_init(dbus GDBusConnection, opts Options) !string {
	pid := os.getpid()

	// Get our initial cgroup so we can detect the switch to the transient one.
	original := cgroup_current(pid) or { '' }

	// Create our transient scope. If this succeeds the unit was created but we
	// may not have moved into it yet, so busy-loop until the move completes.
	create_scope(dbus, pid)!
	mut transient := ''
	for {
		current := cgroup_current(pid) or { '' }
		if current != original {
			transient = current
			break
		}
		// Sleep 25ms between polls, matching the Zig original.
		sleep_ms(25)
	}
	// log.info("transient scope created cgroup={s}", .{transient});

	// Create the app cgroup and move ourselves into it. This is required
	// because controllers can't be configured while a process is in a cgroup.
	cgroup_create(transient, 'app', pid)!

	// Create a cgroup that will contain all our surfaces. Controllers/limits are
	// configured only on this cgroup so the main app is unaffected.
	cgroup_create(transient, 'surfaces', -1)!
	surfaces := '${transient}/surfaces'

	// Enable all of our cgroup controllers. In the Zig original failures here
	// only get logged; we propagate the error which callers may choose to
	// tolerate.
	enable_controllers(transient)!
	enable_controllers(surfaces)!

	// Configure the "high" (soft) memory limit if requested.
	if limit := opts.memory_high {
		cgroup_configure_memory_high(surfaces, limit)!
	}

	// Configure the "max" (hard) pids limit if requested.
	if limit := opts.pids_max {
		cgroup_configure_pids_max(surfaces, limit)!
	}

	return transient
}

// create_scope creates a transient systemd scope unit for the current process
// and moves the process into it, via a D-Bus StartTransientUnit call. Mirrors
// `createScope`.
fn create_scope(dbus GDBusConnection, pid_ int) ! {
	pid := u32(pid_)

	// The unit name needs to be unique; use the pid.
	name := 'app-ghostty-transient-${pid}.scope'

	builder_type := C.g_variant_type_new(c'(ssa(sv)a(sa(sv)))')
	defer {
		C.g_variant_type_free(builder_type)
	}

	// Initialize our builder to build up our parameters.
	builder := C.g_variant_builder_new(builder_type)

	// s: unit name
	C.g_variant_builder_add_value(builder, C.g_variant_new_string(&char(name.str)))
	// s: mode "fail"
	C.g_variant_builder_add_value(builder, C.g_variant_new_string(c'fail'))

	// a(sv): properties
	properties_type := C.g_variant_type_new(c'a(sv)')
	C.g_variant_builder_open(builder, properties_type)

	// ManagedOOMMemoryPressure = "kill"
	// https://www.freedesktop.org/software/systemd/man/latest/systemd-oomd.service.html
	add_sv(builder, 'ManagedOOMMemoryPressure', C.g_variant_new_string(c'kill'))

	// Delegate = true
	add_sv(builder, 'Delegate', C.g_variant_new_boolean(1))

	// PIDs = [pid] (array of u32); we add a single-element array.
	add_sv(builder, 'PIDs', new_uint32_array(pid))

	C.g_variant_builder_close(builder)
	C.g_variant_type_free(properties_type)

	// a(sa(sv)): aux (empty)
	aux_type := C.g_variant_type_new(c'a(sa(sv))')
	C.g_variant_builder_open(builder, aux_type)
	C.g_variant_builder_close(builder)
	C.g_variant_type_free(aux_type)

	reply_type := C.g_variant_type_new(c'(o)')
	defer {
		C.g_variant_type_free(reply_type)
	}

	value := C.g_variant_builder_end(builder)
	C.g_variant_builder_unref(builder)

	mut call_error := GError(unsafe { nil })
	reply := C.g_dbus_connection_call_sync(dbus, c'org.freedesktop.systemd1',
		c'/org/freedesktop/systemd1', c'org.freedesktop.systemd1.Manager', c'StartTransientUnit',
		value, reply_type, 0, -1, unsafe { nil }, &call_error)
	if isnil(reply) {
		if !isnil(call_error) {
			C.g_error_free(call_error)
		}
		return error('D-Bus StartTransientUnit call failed')
	}
	C.g_variant_unref(reply)
	if !isnil(call_error) {
		C.g_error_free(call_error)
	}
}

// add_sv appends a "(sv)" tuple (string key -> variant value) to the
// builder. This corresponds to the Zig `builder.add("(sv)", key, value)` calls.
fn add_sv(builder GVariantBuilder, key string, value GVariant) {
	mut children := [
		C.g_variant_new_string(&char(key.str)),
		C.g_variant_new_variant(value),
	]
	tuple := C.g_variant_new_tuple(unsafe { &children[0] }, usize(children.len))
	C.g_variant_builder_add_value(builder, tuple)
}

// new_property_array builds the systemd `a(sv)` property payload used by
// StartTransientUnit. Keeping this construction separate also lets us verify
// the exact tuple signature without making a D-Bus call.
fn new_property_array(key string, value GVariant) GVariant {
	properties_type := C.g_variant_type_new(c'a(sv)')
	builder := C.g_variant_builder_new(properties_type)
	C.g_variant_type_free(properties_type)
	add_sv(builder, key, value)
	result := C.g_variant_builder_end(builder)
	C.g_variant_builder_unref(builder)
	return result
}

// new_uint32_array builds a GVariant array "au" containing a single u32.
// Mirrors the `glib.Variant.newFixedArray(u, &pid, 1, ...)` call in the Zig
// original (a fixed array of one 32-bit unsigned int).
fn new_uint32_array(v u32) GVariant {
	arr_type := C.g_variant_type_new(c'au')
	ab := C.g_variant_builder_new(arr_type)
	C.g_variant_builder_add_value(ab, C.g_variant_new_uint32(v))
	result := C.g_variant_builder_end(ab)
	C.g_variant_builder_unref(ab)
	C.g_variant_type_free(arr_type)
	return result
}

// sleep_ms sleeps for the given number of milliseconds. Uses the POSIX
// nanosleep via a minimal local binding to avoid pulling in `time` here.
fn C.usleep(usec u32) int

fn sleep_ms(ms int) {
	C.usleep(u32(ms) * 1000)
}
