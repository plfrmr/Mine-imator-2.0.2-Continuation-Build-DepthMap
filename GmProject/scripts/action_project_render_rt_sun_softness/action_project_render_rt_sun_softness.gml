/// action_project_render_rt_sun_softness(value, add)
/// @arg value
/// @arg add

function action_project_render_rt_sun_softness(val, add)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_rt_sun_softness, project_render_rt_sun_softness, project_render_rt_sun_softness * add + val, 1)

	project_render_rt_sun_softness = project_render_rt_sun_softness * add + val
	render_samples = -1
}
