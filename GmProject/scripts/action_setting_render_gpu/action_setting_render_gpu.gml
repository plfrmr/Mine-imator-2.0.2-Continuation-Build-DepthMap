/// action_setting_render_gpu(name)
/// @arg name
/// @desc Sets the preferred graphics card ("" = system default, "highperformance" = automatic). Applied when Mine-imator restarts.

function action_setting_render_gpu(name)
{
	render_gpu_preferred = name
	gpu_adapter_set_preferred(name)
}
