/// action_project_render_rt_roughness_cutoff(value, add)
/// @arg value
/// @arg add

function action_project_render_rt_roughness_cutoff(val, add)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_rt_roughness_cutoff, project_render_rt_roughness_cutoff, project_render_rt_roughness_cutoff * add + val / 100, 1)
	else
		val *= 100

	project_render_rt_roughness_cutoff = project_render_rt_roughness_cutoff * add + val / 100
	render_samples = -1
}
