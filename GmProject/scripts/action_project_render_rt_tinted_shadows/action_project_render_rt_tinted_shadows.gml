/// action_project_render_rt_tinted_shadows(enable)
/// @arg enable

function action_project_render_rt_tinted_shadows(enable)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_rt_tinted_shadows, project_render_rt_tinted_shadows, enable, true)

	project_render_rt_tinted_shadows = enable
	render_samples = -1
}
