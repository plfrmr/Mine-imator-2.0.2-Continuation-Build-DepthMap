/// action_project_render_rt_clamp(value, add)
/// @arg value
/// @arg add

function action_project_render_rt_clamp(val, add)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_rt_clamp, project_render_rt_clamp, project_render_rt_clamp * add + val, 1)

	project_render_rt_clamp = project_render_rt_clamp * add + val
	render_samples = -1
}
