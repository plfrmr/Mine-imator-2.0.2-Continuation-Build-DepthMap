/// action_project_render_depth_map_near(value, add)
/// @arg value
/// @arg add

function action_project_render_depth_map_near(val, add)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_depth_map_near, project_render_depth_map_near, project_render_depth_map_near * add + val, 1)
	
	project_render_depth_map_near = project_render_depth_map_near * add + val
	render_samples = -1
}
