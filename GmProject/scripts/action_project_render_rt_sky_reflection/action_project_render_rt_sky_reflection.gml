/// action_project_render_rt_sky_reflection(value, add)
/// @arg value
/// @arg add

function action_project_render_rt_sky_reflection(val, add)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_rt_sky_reflection, project_render_rt_sky_reflection, project_render_rt_sky_reflection * add + val / 100, 1)
	else
		val *= 100

	project_render_rt_sky_reflection = project_render_rt_sky_reflection * add + val / 100
	render_samples = -1
}
