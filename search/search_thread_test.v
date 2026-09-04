module search

import sync
import terminal
import time

struct SearchThreadTestEvents {
	events chan Event
}

fn search_thread_test_callback(event Event, userdata voidptr) {
	state := unsafe { &SearchThreadTestEvents(userdata) }
	state.events <- event
}

fn test_search_thread_processes_messages_asynchronously() {
	mut term := terminal.Terminal.init(terminal.Options{
		cols: 20
		rows: 2
	})!
	defer { term.deinit() }
	term.print_string('Hello, world')!

	mutex := sync.new_mutex()
	defer { mutex.destroy() }
	events := SearchThreadTestEvents{
		events: chan Event{ cap: 32 }
	}
	mut worker := SearchThread.init(ThreadOptions{
		mutex: mutex
		terminal: &term
		event_cb: search_thread_test_callback
		event_userdata: voidptr(&events)
	})!
	thread_ := spawn worker.thread_main()

	worker.push(Message.change_needle('world'.bytes()))
	mut total := -1
	mut complete := false
	for !complete {
		select {
			event := <-events.events {
				match event.kind {
					.total_matches {
						total = event.total
					}
					.complete {
						complete = true
					}
					else {}
				}
			}
			2 * time.second {
				assert false, 'timed out waiting for asynchronous search completion'
				break
			}
		}
	}

	assert total == 1
	worker.request_stop()
	thread_.wait()
	quit_event := <-events.events
	assert quit_event.kind == .quit
	worker.deinit()
}

fn test_search_thread_requires_shared_terminal_state() {
	SearchThread.init(ThreadOptions{}) or {
		assert err.msg() == 'search thread requires a terminal and mutex'
		return
	}
	assert false, 'initialization without a terminal and mutex must fail'
}
