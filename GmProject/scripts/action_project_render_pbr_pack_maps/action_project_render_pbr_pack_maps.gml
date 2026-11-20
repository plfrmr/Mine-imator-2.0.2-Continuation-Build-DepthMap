/// action_project_render_pbr_pack_maps(enable)
/// @arg enable

function action_project_render_pbr_pack_maps(enable)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_pbr_pack_maps, project_render_pbr_pack_maps, enable, true)

	project_render_pbr_pack_maps = enable
	render_samples = -1
}
