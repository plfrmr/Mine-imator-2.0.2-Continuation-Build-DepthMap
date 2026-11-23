/// action_project_render_ok_roulette(value, add)
/// @arg value
/// @arg add

function action_project_render_ok_roulette(val, add)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_ok_roulette, project_render_ok_roulette, project_render_ok_roulette * add + val, 1)

	project_render_ok_roulette = project_render_ok_roulette * add + val
	render_samples = -1
}
