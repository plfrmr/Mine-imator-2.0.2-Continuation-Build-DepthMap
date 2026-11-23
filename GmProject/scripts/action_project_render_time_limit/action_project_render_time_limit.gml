/// action_project_render_time_limit(value, add)
/// @arg value
/// @arg add

function action_project_render_time_limit(val, add)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_time_limit, project_render_time_limit, project_render_time_limit * add + val, 1)

	project_render_time_limit = project_render_time_limit * add + val
	render_samples = -1
}
