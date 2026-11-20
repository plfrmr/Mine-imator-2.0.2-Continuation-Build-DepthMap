/// action_project_render_rt_samples(value, add)
/// @arg value
/// @arg add

function action_project_render_rt_samples(val, add)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_rt_samples, project_render_rt_samples, project_render_rt_samples * add + val, 1)

	project_render_rt_samples = project_render_rt_samples * add + val
	render_samples = -1
}
