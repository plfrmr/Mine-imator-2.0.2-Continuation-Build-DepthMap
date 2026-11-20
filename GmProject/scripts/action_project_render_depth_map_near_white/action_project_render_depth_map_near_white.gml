/// action_project_render_depth_map_near_white(value)
/// @arg value

function action_project_render_depth_map_near_white(value)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_depth_map_near_white, project_render_depth_map_near_white, value, 1)
	
	project_render_depth_map_near_white = value
	render_samples = -1
}
