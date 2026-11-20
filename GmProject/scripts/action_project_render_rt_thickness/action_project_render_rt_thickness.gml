/// action_project_render_rt_thickness(value, add)
/// @arg value
/// @arg add

function action_project_render_rt_thickness(val, add)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_rt_thickness, project_render_rt_thickness, project_render_rt_thickness * add + val / 100, 1)
	else
		val *= 100

	project_render_rt_thickness = project_render_rt_thickness * add + val / 100
	render_samples = -1
}
