/// action_project_render_rt_distance(value, add)
/// @arg value
/// @arg add

function action_project_render_rt_distance(val, add)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_rt_distance, project_render_rt_distance, project_render_rt_distance * add + val, 1)

	project_render_rt_distance = project_render_rt_distance * add + val
	render_samples = -1
}
