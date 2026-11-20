/// action_project_render_depth_map_far(value, add)
/// @arg value
/// @arg add

function action_project_render_depth_map_far(val, add)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_depth_map_far, project_render_depth_map_far, project_render_depth_map_far * add + val, 1)
	
	project_render_depth_map_far = project_render_depth_map_far * add + val
	render_samples = -1
}
