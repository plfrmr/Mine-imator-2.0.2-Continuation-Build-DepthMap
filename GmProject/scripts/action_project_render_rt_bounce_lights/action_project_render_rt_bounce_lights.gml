/// action_project_render_rt_bounce_lights(enable)
/// @arg enable

function action_project_render_rt_bounce_lights(enable)
{
	if (!history_undo && !history_redo)
		history_set_var(action_project_render_rt_bounce_lights, project_render_rt_bounce_lights, enable, true)

	project_render_rt_bounce_lights = enable
	render_samples = -1
}
