/// action_project_render_rt_shadows(enable)
/// @arg enable

function action_project_render_rt_shadows(enable)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_rt_shadows, project_render_rt_shadows, enable, true)

	project_render_rt_shadows = enable
	render_samples = -1
}
