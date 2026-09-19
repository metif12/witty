module cli

import internal_os
import net
import os
import os.filelock
import time
import zig_fmt

const max_ssh_cache_size = 512 * 1024

pub struct SshCacheEntry {
pub:
	hostname         string
	timestamp        i64
	terminfo_version string
}

pub fn SshCacheEntry.parse(line string) ?SshCacheEntry {
	trimmed := line.trim(' \t\r\n')
	if trimmed.len == 0 {
		return none
	}
	parts := trimmed.split('|').filter(it.len > 0)
	if parts.len < 2 {
		return none
	}
	timestamp := parse_ssh_timestamp(parts[1]) or { return none }
	return SshCacheEntry{
		hostname: parts[0]
		timestamp: timestamp
		terminfo_version: if parts.len >= 3 { parts[2] } else { 'xterm-ghostty' }
	}
}

// Direct translation of `std.fmt.parseInt(i64, timestamp, 10)`.
fn parse_ssh_timestamp(input string) ?i64 {
	return zig_fmt.parse_int_signed(input, 64, 10) or { return none }
}

pub fn (entry SshCacheEntry) format() string {
	return '${entry.hostname}|${entry.timestamp}|${entry.terminfo_version}\n'
}

pub fn (entry SshCacheEntry) is_expired(expire_days ?u32) bool {
	days := expire_days or { return false }
	age_seconds := saturating_sub_i64(time.now().unix(), entry.timestamp)
	return age_seconds / i64(24 * 60 * 60) > i64(days)
}

pub enum SshCacheAddResult as u8 {
	added
	updated
}

pub struct SshDiskCache {
pub:
	path string
}

// ssh_cache_default_path resolves `${XDG_STATE_HOME}/<program>/ssh_cache`
// without creating the directory. Path creation belongs to cache mutation.
pub fn ssh_cache_default_path(program string) !string {
	state_dir := internal_os.xdg_state(internal_os.XdgOptions{ subdir: program })!
	return os.join_path(state_dir, 'ssh_cache')
}

pub fn (cache SshDiskCache) clear() ! {
	os.rm(cache.path) or {
		if os.exists(cache.path) {
			return err
		}
	}
}

pub fn (cache SshDiskCache) add(hostname string) !SshCacheAddResult {
	if !valid_ssh_cache_key(hostname) {
		return error('hostname is invalid')
	}
	cache.ensure_file()!
	mut file_lock := filelock.new_file(cache.path, filelock.LockOptions{})
	mut acquired := false
	$if !windows {
		if !file_lock.try_acquire() {
			return error('cache is locked')
		}
		acquired = true
	}
	defer {
		if acquired {
			file_lock.release()
		}
	}

	mut entries := cache.read_entries()!
	result := if hostname in entries { SshCacheAddResult.updated } else { SshCacheAddResult.added }
	terminfo_version := if existing := entries[hostname] {
		existing.terminfo_version
	} else {
		'xterm-ghostty'
	}
	entries[hostname] = SshCacheEntry{
		hostname: hostname
		timestamp: time.now().unix()
		terminfo_version: terminfo_version
	}
	cache.write_entries(entries, none)!
	return result
}

pub fn (cache SshDiskCache) remove(hostname string) ! {
	if !valid_ssh_cache_key(hostname) {
		return error('hostname is invalid')
	}
	if !os.exists(cache.path) {
		return
	}
	os.chmod(cache.path, 0o600)!
	mut file_lock := filelock.new_file(cache.path, filelock.LockOptions{})
	mut acquired := false
	$if !windows {
		if !file_lock.try_acquire() {
			return error('cache is locked')
		}
		acquired = true
	}
	defer {
		if acquired {
			file_lock.release()
		}
	}
	mut entries := cache.read_entries()!
	entries.delete(hostname)
	cache.write_entries(entries, none)!
}

pub fn (cache SshDiskCache) contains(hostname string) !bool {
	if !valid_ssh_cache_key(hostname) {
		return error('hostname is invalid')
	}
	entries := cache.read_entries()!
	return hostname in entries
}

pub fn (cache SshDiskCache) list() !map[string]SshCacheEntry {
	return cache.read_entries()
}

fn (cache SshDiskCache) ensure_file() ! {
	dir := os.dir(cache.path)
	if dir.len == 0 || dir == '.' {
		return error('invalid cache path')
	}
	os.mkdir_all(dir)!
	if !os.exists(cache.path) {
		mut file := os.create(cache.path)!
		file.close()
	}
	os.chmod(cache.path, 0o600)!
}

fn (cache SshDiskCache) read_entries() !map[string]SshCacheEntry {
	mut result := map[string]SshCacheEntry{}
	if !os.exists(cache.path) {
		return result
	}
	if os.file_size(cache.path) > max_ssh_cache_size {
		return error('cache exceeds maximum size')
	}
	content := os.read_file(cache.path)!
	for line in content.split_into_lines() {
		entry := SshCacheEntry.parse(line) or { continue }
		if existing := result[entry.hostname] {
			if entry.timestamp <= existing.timestamp {
				continue
			}
		}
		result[entry.hostname] = entry
	}
	return result
}

fn (cache SshDiskCache) write_entries(entries map[string]SshCacheEntry, expire_days ?u32) ! {
	dir := os.dir(cache.path)
	if dir.len == 0 || dir == '.' {
		return error('invalid cache path')
	}
	os.mkdir_all(dir)!
	temporary := '${cache.path}.tmp-${os.getpid()}'
	defer {
		if os.exists(temporary) {
			os.rm(temporary) or {}
		}
	}
	mut output := ''
	for _, entry in entries {
		if !entry.is_expired(expire_days) {
			output += entry.format()
		}
	}
	os.write_file(temporary, output)!
	os.chmod(temporary, 0o600)!
	os.rename(temporary, cache.path)!
}

pub fn valid_ssh_cache_key(key string) bool {
	if key.len == 0 {
		return false
	}
	at := key.index_u8(`@`)
	if at >= 0 {
		return valid_ssh_user(key[..at]) && valid_ssh_host(key[at + 1..])
	}
	return valid_ssh_host(key)
}

fn valid_ssh_host(host string) bool {
	if internal_os.hostname_is_valid(host) {
		return true
	}
	_ := net.canonical_ipv6(host) or { return false }
	return true
}

fn valid_ssh_user(user string) bool {
	if user.len == 0 || user.len > 64 {
		return false
	}
	for c in user.bytes() {
		if !c.is_alnum() && c !in [`_`, `-`, `.`] {
			return false
		}
	}
	return true
}

fn saturating_sub_i64(lhs i64, rhs i64) i64 {
	if rhs >= lhs {
		return 0
	}
	if rhs < 0 && lhs > max_i64 + rhs {
		return max_i64
	}
	return lhs - rhs
}

pub struct SshCacheOptions {
pub mut:
	clear       bool
	add         ?string
	remove      ?string
	host        ?string
	expire_days ?u32
}

pub struct SshCacheResult {
pub:
	code   int
	output string
	errors string
}

pub fn ssh_cache(args []string) !SshCacheResult {
	opts := parse_ssh_cache_options(args)!
	cache := SshDiskCache{
		path: ssh_cache_default_path('ghostty')!
	}
	return run_ssh_cache_with(cache, opts)
}

fn run_ssh_cache_with(cache SshDiskCache, opts SshCacheOptions) !SshCacheResult {
	// This is parsed by upstream but currently not forwarded to DiskCache.
	_ = opts.expire_days
	if opts.clear {
		cache.clear()!
		return SshCacheResult{ output: 'Cache cleared.\n' }
	}
	if host := opts.add {
		result := cache.add(host) or { return ssh_cache_operation_error('add', host, err) }
		return SshCacheResult{
			output: match result {
				.added { "Added '${host}' to cache.\n" }
				.updated { "Updated '${host}' cache entry.\n" }
			}
		}
	}
	if host := opts.remove {
		cache.remove(host) or { return ssh_cache_operation_error('remove', host, err) }
		return SshCacheResult{ output: "Removed '${host}' from cache.\n" }
	}
	if host := opts.host {
		cached := cache.contains(host) or { return ssh_cache_operation_error('check', host, err) }
		return SshCacheResult{
			code: if cached { 0 } else { 1 }
			output: if cached {
				"'${host}' has Ghostty terminfo installed.\n"
			} else {
				"'${host}' does not have Ghostty terminfo installed.\n"
			}
		}
	}
	entries := cache.list()!
	return SshCacheResult{ output: format_ssh_cache_entries(entries, time.now().unix()) }
}

pub fn run_ssh_cache(args []string) !int {
	result := ssh_cache(args)!
	print(result.output)
	eprint(result.errors)
	return result.code
}

fn parse_ssh_cache_options(args []string) !SshCacheOptions {
	return parse_action_options[SshCacheOptions](args)
}

fn ssh_cache_operation_error(operation string, host string, err IError) SshCacheResult {
	if err.msg() == 'hostname is invalid' {
		return SshCacheResult{
			code: 1
			errors: "Error: Invalid hostname format '${host}'\nExpected format: hostname or user@hostname\n"
		}
	}
	if err.msg() == 'cache is locked' {
		return SshCacheResult{
			code: 1
			errors: 'Error: Cache is busy, try again\n'
		}
	}
	description := match operation {
		'add' { "add '${host}' to cache" }
		'remove' { "remove '${host}' from cache" }
		else { "check host '${host}' in cache" }
	}
	return SshCacheResult{
		code: 1
		errors: 'Error: Unable to ${description}. Error: ${err}\n'
	}
}

fn format_ssh_cache_entries(entries map[string]SshCacheEntry, now i64) string {
	if entries.len == 0 {
		return 'No hosts in cache.\n'
	}
	mut values := entries.values()
	values.sort(a.hostname < b.hostname)
	mut lines := ['Cached hosts (${values.len}):']
	for entry in values {
		age_days := (now - entry.timestamp) / i64(24 * 60 * 60)
		age := if age_days == 0 {
			'today'
		} else if age_days == 1 {
			'yesterday'
		} else {
			'${age_days} days ago'
		}
		lines << '  ${entry.hostname} (${age})'
	}
	return output_lines(lines)
}
