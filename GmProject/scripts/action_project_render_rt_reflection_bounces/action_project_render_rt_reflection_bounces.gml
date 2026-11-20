/// action_project_render_rt_reflection_bounces(value, add)
/// @arg value
/// @arg add

function action_project_render_rt_reflection_bounces(val, add)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_rt_reflection_bounces, project_render_rt_reflection_bounces, project_render_rt_reflection_bounces * add + val, 1)

	project_render_rt_reflection_bounces = project_render_rt_reflection_bounces * add + val
	render_samples = -1
}
