/// action_project_render_ok_paths(value, add)
/// @arg value
/// @arg add

function action_project_render_ok_paths(val, add)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_ok_paths, project_render_ok_paths, project_render_ok_paths * add + val, 1)

	project_render_ok_paths = project_render_ok_paths * add + val
	render_samples = -1
}
