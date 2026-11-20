/// action_project_render_rt_ray_offset(value, add)
/// @arg value
/// @arg add

function action_project_render_rt_ray_offset(val, add)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_rt_ray_offset, project_render_rt_ray_offset, project_render_rt_ray_offset * add + val, 1)

	project_render_rt_ray_offset = project_render_rt_ray_offset * add + val
	render_samples = -1
}
