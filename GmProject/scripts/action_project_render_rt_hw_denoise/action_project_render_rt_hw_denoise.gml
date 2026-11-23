/// action_project_render_rt_hw_denoise(enable)
/// @arg enable

function action_project_render_rt_hw_denoise(enable)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_rt_hw_denoise, project_render_rt_hw_denoise, enable, true)

	project_render_rt_hw_denoise = enable
	render_samples = -1
}
