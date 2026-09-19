module renderer

import sync
import time
import configpkg
import internal_os

struct RedrawCapture {
mut:
	count int
}

fn capture_redraw(data voidptr) {
	mut capture := unsafe { &RedrawCapture(data) }
	capture.count++
}

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
	assert cursor_blink_interval_for_valgrind(0) == 600 * u64(time.millisecond)
	assert cursor_blink_interval_for_valgrind(1) == 3_000 * u64(time.millisecond)
	assert cursor_blink_interval_for_valgrind(2) == 3_000 * u64(time.millisecond)
	assert cursor_blink_interval() == cursor_blink_interval_for_valgrind(internal_os.running_on_valgrind())
	assert draw_interval_ns() == 8 * u64(time.millisecond)

	render_thread := RendererThread{
		cursor_blink_active: true
		next_cursor_blink_at: 2_000
		draw_active: true
		draw_timer_armed: true
		next_draw_at: 1_000
	}
	assert render_thread.next_timer_timeout(500) == 500
	assert render_thread.next_timer_timeout(1_000) == 0
}

fn test_renderer_thread_flags_match_source_defaults() {
	flags := ThreadFlags{}
	assert !flags.cursor_blink_visible()
	assert !flags.has_inspector()
	assert flags.visible()
	assert flags.focused()
	assert sizeof(ThreadFlags) == 1
}

fn test_renderer_thread_derived_config_retains_shader_animation_type() {
	mut config := configpkg.Config.default_config()
	for animation in [configpkg.CustomShaderAnimation.false_, .true_, .always] {
		config.custom_shader_animation = animation
		derived := ThreadDerivedConfig.init(&config)
		assert derived.custom_shader_animation == animation
	}
}

fn test_renderer_thread_disabled_draw_keeps_armed_completion() {
	mut render := Renderer{}
	mut flags := ThreadFlags{}
	flags.set_visible(false)
	mut render_thread := RendererThread{
		renderer: &render
		config: ThreadDerivedConfig{
			custom_shader_animation: .false_
		}
		flags: flags
		draw_active: true
		draw_timer_armed: true
		next_draw_at: 123
	}
	render_thread.sync_draw_timer()
	assert !render_thread.draw_active
	assert render_thread.draw_timer_armed
	assert render_thread.next_draw_at == 123

	render_thread.draw_timer_callback()
	assert !render_thread.draw_timer_armed
}

fn test_renderer_thread_active_draw_rearms_completion() {
	mut render := Renderer{}
	mut flags := ThreadFlags{}
	flags.set_visible(false)
	mut render_thread := RendererThread{
		renderer: &render
		config: ThreadDerivedConfig{
			custom_shader_animation: .always
		}
		flags: flags
		draw_active: true
		draw_timer_armed: true
		next_draw_at: 123
	}
	before := time.sys_mono_now()
	render_thread.draw_timer_callback()
	assert render_thread.draw_timer_armed
	assert render_thread.next_draw_at >= before + draw_interval_ns()
}

fn test_renderer_thread_routes_app_thread_draws_through_redraw_callback() {
	mut capture := RedrawCapture{}
	mut render := Renderer{}
	mut render_thread := RendererThread{
		renderer: &render
		draw_from_app_thread: true
		app_redraw: Wakeup{
			user_data: voidptr(&capture)
			notify_fn: capture_redraw
		}
	}
	render_thread.draw_frame(false)
	assert capture.count == 1

	render_thread.flags.set_visible(false)
	render_thread.draw_frame(true)
	assert capture.count == 1
}
