/// action_project_render_hdr_paper_white(value, add)
/// @arg value
/// @arg add

function action_project_render_hdr_paper_white(val, add)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_hdr_paper_white, project_render_hdr_paper_white, project_render_hdr_paper_white * add + val, 1)

	project_render_hdr_paper_white = project_render_hdr_paper_white * add + val
}
