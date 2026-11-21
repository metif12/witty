module xev

// Port of backend/wasi_poll.zig Batch tests. The subscription timeout at
// index zero is reserved and removal must relocate the final completion.
fn test_wasi_batch_source_capacity_and_swap() {
	$if !windows {
		mut batch := WasiBatch{}
		assert batch.len == 1
		mut completions := []WasiCompletion{len: wasi_batch_capacity - 1}
		for i in 0 .. completions.len {
			c := unsafe { &completions[i] }
			mut subscription := batch.get(c) or { panic(err) }
			subscription.userdata = u64(uint(c))
			assert completions[i].batch_idx == uint(i + 1)
		}
		assert batch.len == wasi_batch_capacity
		mut overflow := WasiCompletion{}
		batch.get(&overflow) or {
			assert error_kind(err) == .batch_full
			old := completions[4].batch_idx
			replacement := unsafe { &completions[completions.len - 1] }
			batch.put(unsafe { &completions[4] })
			assert batch.len == wasi_batch_capacity - 1
			assert batch.array[int(old)].userdata == u64(uint(replacement))
			assert replacement.batch_idx == old
			mut restored := batch.get(unsafe { &completions[4] }) or { panic(err) }
			restored.userdata = u64(uint(unsafe { &completions[4] }))
			assert completions[4].batch_idx == wasi_batch_capacity - 1
			return
		}
		assert false, 'full batch accepted an extra subscription'
	}
}

fn test_wasi_subscription_abi() {
	$if !windows {
		assert sizeof(WasiSubscription) == 48
		assert __offsetof(WasiSubscription, u) == 8
		assert __offsetof(WasiSubscriptionPayload, u) == 8
		assert sizeof(WasiEvent) == 32
		assert __offsetof(WasiEvent, fd_readwrite) == 16
	}
}
