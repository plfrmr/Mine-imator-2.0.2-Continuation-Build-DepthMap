/// action_project_render_pbr_parallax(enable)
/// @arg enable

function action_project_render_pbr_parallax(enable)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_pbr_parallax, project_render_pbr_parallax, enable, true)

	project_render_pbr_parallax = enable
	render_samples = -1
}