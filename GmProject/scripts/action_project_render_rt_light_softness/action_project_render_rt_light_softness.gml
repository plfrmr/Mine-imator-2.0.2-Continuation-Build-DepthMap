/// action_project_render_rt_light_softness(value, add)
/// @arg value
/// @arg add

function action_project_render_rt_light_softness(val, add)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_rt_light_softness, project_render_rt_light_softness, project_render_rt_light_softness * add + val / 100, 1)
	else
		val *= 100

	project_render_rt_light_softness = project_render_rt_light_softness * add + val / 100
	render_samples = -1
}
