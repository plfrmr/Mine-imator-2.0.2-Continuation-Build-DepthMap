/// action_project_render_rt_hardware(enable)
/// @arg enable

function action_project_render_rt_hardware(enable)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_rt_hardware, project_render_rt_hardware, enable, true)

	project_render_rt_hardware = enable
	render_samples = -1
}
