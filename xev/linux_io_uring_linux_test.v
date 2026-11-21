module xev

// The "structs/offsets/entries" test from Zig 0.15.2
// lib/std/os/linux/IoUring.zig. The other std tests exercise IoUring methods
// that libxev does not reach and are not translated.

fn test_linux_io_uring_structs_offsets_entries() {
	assert uint(120) == sizeof(IoUringParams)
	assert uint(64) == sizeof(IoUringSqe)
	assert uint(16) == sizeof(IoUringCqe)

	assert 0 == ioring_off_sq_ring
	assert 0x8000000 == ioring_off_cq_ring
	assert 0x10000000 == ioring_off_sqes

	if mut ring := LinuxIoUring.init(0, 0) {
		ring.deinit()
		assert false, 'expected error.EntriesZero'
	} else {
		assert error_kind(err) == .entries_zero
	}
	if mut ring := LinuxIoUring.init(3, 0) {
		ring.deinit()
		assert false, 'expected error.EntriesNotPowerOfTwo'
	} else {
		assert error_kind(err) == .entries_not_power_of_two
	}
}
