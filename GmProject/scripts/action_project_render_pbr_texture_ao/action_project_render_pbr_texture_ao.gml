/// action_project_render_pbr_texture_ao(enable)
/// @arg enable

function action_project_render_pbr_texture_ao(enable)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_pbr_texture_ao, project_render_pbr_texture_ao, enable, true)

	project_render_pbr_texture_ao = enable
	render_samples = -1
}
