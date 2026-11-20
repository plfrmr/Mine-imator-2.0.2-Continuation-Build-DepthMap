/// action_project_render_rt_specular(enable)
/// @arg enable

function action_project_render_rt_specular(enable)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_rt_specular, project_render_rt_specular, enable, true)

	project_render_rt_specular = enable
	render_samples = -1
}
