/// shader_high_depth_map_set(depthbuffer)
/// @arg depthbuffer

function shader_high_depth_map_set(depthbuffer)
{
	texture_set_stage(sampler_map[?"uDepthBuffer"], surface_get_texture(depthbuffer))
	gpu_set_texfilter_ext(sampler_map[?"uDepthBuffer"], false)
	
	// Same range as used when packing the depth buffer (see shader_high_depth_normal_set)
	render_set_uniform("uNear", depth_near)
	render_set_uniform("uFar", depth_far)
	
	render_set_uniform("uMapNear", app.project_render_depth_map_near)
	render_set_uniform("uMapFar", app.project_render_depth_map_far)
	render_set_uniform_int("uNearWhite", app.project_render_depth_map_near_white)
}
