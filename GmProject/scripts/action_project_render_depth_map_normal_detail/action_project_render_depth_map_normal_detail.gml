/// action_project_render_depth_map_normal_detail(enable)
/// @arg enable

function action_project_render_depth_map_normal_detail(enable)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_depth_map_normal_detail, project_render_depth_map_normal_detail, enable, true)

	project_render_depth_map_normal_detail = enable
	render_samples = -1
}
