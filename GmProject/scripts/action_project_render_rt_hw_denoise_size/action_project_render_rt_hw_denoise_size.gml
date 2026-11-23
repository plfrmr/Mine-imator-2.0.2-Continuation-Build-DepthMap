/// action_project_render_rt_hw_denoise_size(value, add)
/// @arg value
/// @arg add

function action_project_render_rt_hw_denoise_size(val, add)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_rt_hw_denoise_size, project_render_rt_hw_denoise_size, project_render_rt_hw_denoise_size * add + val / 100, 1)
	else
		val *= 100

	project_render_rt_hw_denoise_size = project_render_rt_hw_denoise_size * add + val / 100
	render_samples = -1
}
