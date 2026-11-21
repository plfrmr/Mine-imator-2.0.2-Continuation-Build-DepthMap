/// action_project_render_pbr_parallax_shadow(enable)
/// @arg enable

function action_project_render_pbr_parallax_shadow(enable)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_pbr_parallax_shadow, project_render_pbr_parallax_shadow, enable, true)

	project_render_pbr_parallax_shadow = enable
	render_samples = -1
}