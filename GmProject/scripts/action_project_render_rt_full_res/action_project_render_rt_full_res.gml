/// action_project_render_rt_full_res(enable)
/// @arg enable

function action_project_render_rt_full_res(enable)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_rt_full_res, project_render_rt_full_res, enable, true)

	project_render_rt_full_res = enable
	render_samples = -1
}
