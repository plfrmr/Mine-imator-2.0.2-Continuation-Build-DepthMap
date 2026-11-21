/// action_project_render_hdr_peak(value, add)
/// @arg value
/// @arg add

function action_project_render_hdr_peak(val, add)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_hdr_peak, project_render_hdr_peak, project_render_hdr_peak * add + val, 1)

	project_render_hdr_peak = project_render_hdr_peak * add + val
}
