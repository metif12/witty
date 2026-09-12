module apprt

import configpkg
import input
import osc

fn test_c_action_and_target_layouts_match_header() {
	assert sizeof(CAPITarget) == 16
	assert sizeof(CAPIAction) == 32
	assert sizeof(CAPIInputTrigger) == 12
	assert sizeof(CAPIClipboardContentC) == 16

	mut surface := Surface{}
	mut core_surface := CoreSurface{ runtime_surface: voidptr(&surface) }
	target := Target(SurfaceTarget{ surface: voidptr(&core_surface) }).capi()
	assert target.tag == 1
	assert target.target == voidptr(&surface)
	assert Target(AppTarget{}).capi().tag == 0
}

fn test_c_action_projects_enum_struct_and_pointer_payloads() {
	split := RuntimeAction{
		action: .resize_split
		data: ActionValue{
			resize_split_: ResizeSplit{ amount: 42, direction: .left }
		}
	}.capi()
	assert split.tag == int(ActionKey.resize_split)
	split_value := unsafe { &CActionResizeSplit(&split.action[0]) }
	assert split_value.amount == 42
	assert split_value.direction == int(ResizeSplitDirection.left)

	url_text := 'https://example.com/path'
	url := RuntimeAction{
		action: .open_url
		data: ActionValue{
			open_url_: OpenUrl{ kind: .html, url: url_text }
		}
	}.capi()
	url_value := unsafe { &CActionTaggedSlice(&url.action[0]) }
	assert url_value.tag == int(OpenUrlKind.html)
	assert url_value.len == usize(url_text.len)
	assert unsafe { tos(url_value.ptr, int(url_value.len)) } == url_text

	config := configpkg.Config.default_config()
	changed := RuntimeAction{
		action: .config_change
		data: ActionValue{
			config_change_: ConfigChange{ config: &config }
		}
	}.capi()
	changed_value := unsafe { &CActionConfigChange(&changed.action[0]) }
	assert changed_value.config == voidptr(&config)
}

fn test_c_action_projects_optional_and_clamped_payloads() {
	missing := RuntimeAction{
		action: .command_finished
		data: ActionValue{
			command_finished_: CommandFinished{
				duration: configpkg.Duration{ duration: 1234 }
			}
		}
	}.capi()
	missing_value := unsafe { &CActionCommandFinished(&missing.action[0]) }
	assert missing_value.exit_code == -1
	assert missing_value.duration == 1234

	progress := RuntimeAction{
		action: .progress_report
		data: ActionValue{
			progress_report_: osc.ProgressReport{
				state: .pause
				progress: u8(250)
			}
		}
	}.capi()
	progress_value := unsafe { &CActionProgressReport(&progress.action[0]) }
	assert progress_value.state == int(osc.ProgressState.pause)
	assert progress_value.progress == 100

	search := RuntimeAction{
		action: .search_total
		data: ActionValue{ search_total_: SearchTotal{} }
	}.capi()
	assert unsafe { &CActionCount(&search.action[0]) }.value == -1

	max_count := usize(~usize(0) >> 1)
	selected := RuntimeAction{
		action: .search_selected
		data: ActionValue{
			search_selected_: SearchSelected{ selected: max_count }
		}
	}.capi()
	assert unsafe { &CActionCount(&selected.action[0]) }.value == isize(max_count)
}

fn test_c_action_key_sequence_end_zeros_ignored_trigger() {
	ended := RuntimeAction{
		action: .key_sequence
		data: ActionValue{
			key_sequence_: KeySequence{
				active: false
				trigger: input.Trigger{
					key: input.TriggerKey.new_physical(.key_a)
					mods: input.Mods.init(false, true, false, false, false, false, input.SideInfo{})
				}
			}
		}
	}.capi()
	value := unsafe { &CActionKeySequence(&ended.action[0]) }
	assert !value.active
	assert value.trigger.tag == 0
	assert value.trigger.key == 0
	assert value.trigger.mods == 0
}
