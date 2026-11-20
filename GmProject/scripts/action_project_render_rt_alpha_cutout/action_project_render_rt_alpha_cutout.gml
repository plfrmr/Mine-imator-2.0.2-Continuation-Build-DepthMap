/// action_project_render_rt_alpha_cutout(enable)
/// @arg enable

function action_project_render_rt_alpha_cutout(enable)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_rt_alpha_cutout, project_render_rt_alpha_cutout, enable, true)

	project_render_rt_alpha_cutout = enable
	render_samples = -1
}
