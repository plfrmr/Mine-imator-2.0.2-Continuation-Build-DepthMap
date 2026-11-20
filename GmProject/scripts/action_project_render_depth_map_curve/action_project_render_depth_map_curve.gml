/// action_project_render_depth_map_curve(value, add)
/// @arg value
/// @arg add

function action_project_render_depth_map_curve(val, add)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_depth_map_curve, project_render_depth_map_curve, project_render_depth_map_curve * add + val, 1)

	project_render_depth_map_curve = project_render_depth_map_curve * add + val
	render_samples = -1
}
