/// shader_high_depth_normal_set()

function shader_high_depth_normal_set()
{
	render_set_uniform("uNormalBufferScale", is_cpp() ? normal_buffer_scale : 1)
	render_set_uniform("uNear", depth_near)
	render_set_uniform("uFar", depth_far)

	// Depth map pass: normal map height detail, as a percentage of the depth map's near-far range
	var heightdepth = 0;
	if (render_pass = e_render_pass.DEPTH_MAP && app.project_render_depth_map_normal_detail && app.project_render_pbr_normal_maps)
		heightdepth = app.project_render_depth_map_detail_depth * app.project_render_pbr_normal_strength * max(0, app.project_render_depth_map_far - app.project_render_depth_map_near) / (depth_far - depth_near)
	render_set_uniform("uHeightDepth", heightdepth)
}
