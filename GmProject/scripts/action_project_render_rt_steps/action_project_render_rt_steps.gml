/// action_project_render_rt_steps(value, add)
/// @arg value
/// @arg add

function action_project_render_rt_steps(val, add)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_rt_steps, project_render_rt_steps, project_render_rt_steps * add + val, 1)

	project_render_rt_steps = project_render_rt_steps * add + val
	render_samples = -1
}
