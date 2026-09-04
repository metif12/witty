module renderer

import sync
import time

fn test_renderer_mailbox_is_bounded_and_fifo() {
	mut mailbox := RendererMailbox.create()
	defer {
		mailbox.destroy()
	}

	for i in 0 .. renderer_mailbox_capacity {
		assert mailbox.push(RendererMessage(InspectorMessage{
			active: i % 2 == 0
		})) == 1
	}
	assert mailbox.push(RendererMessage(InspectorMessage{
		active: true
	})) == 0

	for i in 0 .. renderer_mailbox_capacity {
		msg := mailbox.pop() or {
			assert false, 'message ${i} should be present'
			return
		}
		match msg {
			InspectorMessage {
				assert msg.active == (i % 2 == 0)
			}
			else {
				assert false, 'unexpected renderer message type'
			}
		}
	}
	assert mailbox.pop() == none
}

fn test_renderer_thread_async_event_semantics() {
	mut render_thread := RendererThread{
		event: sync.new_semaphore()
		event_mutex: sync.new_mutex()
	}
	defer {
		render_thread.event.destroy()
		render_thread.event_mutex.destroy()
	}

	render_thread.wakeup()
	render_thread.wakeup()
	render_thread.draw_now()
	render_thread.draw_now()
	render_thread.stop()

	stop, wakeup, draws := render_thread.take_pending_events()
	assert stop
	assert wakeup
	assert draws == 2

	_, wakeup_again, draws_again := render_thread.take_pending_events()
	assert !wakeup_again
	assert draws_again == 0
}

fn test_display_link_callback_queues_draw_now() {
	mut render_thread := RendererThread{
		event: sync.new_semaphore()
		event_mutex: sync.new_mutex()
	}
	defer {
		render_thread.event.destroy()
		render_thread.event_mutex.destroy()
	}

	mut flags_out := u64(0)
	assert renderer_display_link_callback(unsafe { nil }, unsafe { nil }, unsafe { nil }, 0, &flags_out, voidptr(&render_thread)) == 0
	_, _, draws := render_thread.take_pending_events()
	assert draws == 1
}

fn test_renderer_thread_timer_deadlines() {
	assert cursor_blink_interval() == 600 * u64(time.millisecond)
	assert draw_interval_ns() == 8 * u64(time.millisecond)

	render_thread := RendererThread{
		cursor_blink_active: true
		next_cursor_blink_at: 2_000
		draw_active: true
		next_draw_at: 1_000
	}
	assert render_thread.next_timer_timeout(500) == 500
	assert render_thread.next_timer_timeout(1_000) == 0
}
