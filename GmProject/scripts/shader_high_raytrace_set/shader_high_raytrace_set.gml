/// shader_high_raytrace_set(mode, [surf])
/// @arg mode
/// @arg surf

function shader_high_raytrace_set(mode, surf = null)
{
	texture_set_stage(sampler_map[?"uDepthBuffer"], surface_get_texture(render_surface_depth))
	texture_set_stage(sampler_map[?"uNormalBuffer"], surface_get_texture(render_surface_normal))
	texture_set_stage(sampler_map[?"uNoiseBuffer"], surface_get_texture(render_sample_noise_texture))
	texture_set_stage(sampler_map[?"uMaterialBuffer"], surface_get_texture(render_surface_material))
	
	texture_set_stage(sampler_map[?"uDiffuseBuffer"], surface_get_texture(render_surface_diffuse))
	gpu_set_texrepeat_ext(sampler_map[?"uNoiseBuffer"], true)
	
	render_set_uniform_int("uRayType", mode)
	
	render_set_uniform("uNormalBufferScale", is_cpp() ? normal_buffer_scale : 1)
	
	// Raytraced mode uses its own settings, Render mode keeps the original fixed values
	var rt, thickness;
	rt = render_raytraced
	thickness = (rt ? app.project_render_rt_thickness : 1)
	
	render_set_uniform("uRaySteps", rt ? app.project_render_rt_steps : 256)
	render_set_uniform("uFullRes", (rt && app.project_render_rt_full_res) ? 1 : 0)
	render_set_uniform("uRayDistance", rt ? app.project_render_rt_distance : 5000)
	
	if (mode = e_raytrace.INDIRECT)
	{
		render_set_uniform("uPrecision", rt ? app.project_render_rt_precision : app.project_render_indirect_precision)
		render_set_uniform("uThickness", 0.001 * thickness)
		render_set_uniform("uSkyLight", rt ? app.project_render_rt_sky_light : 0)
		
		texture_set_stage(sampler_map[?"uMaterialBuffer"], surface_get_texture(render_surface_emissive))
		texture_set_stage(sampler_map[?"uDataBuffer"], surface_get_texture(render_surface_shadows))
	}
	
	if (mode = e_raytrace.REFLECTIONS)
	{
		render_set_uniform("uPrecision", rt ? app.project_render_rt_precision : app.project_render_reflections_precision)
		render_set_uniform("uThickness", app.project_render_reflections_thickness * thickness)
		render_set_uniform("uSkyLight", 0)
		
		texture_set_stage(sampler_map[?"uDataBuffer"], surface_get_texture(surf))
	}
	
	render_set_uniform("uNoiseSize", render_sample_noise_size)
	render_set_uniform("uNear", depth_near)
	render_set_uniform("uFar", depth_far)
	render_set_uniform("uProjMatrix", proj_matrix)
	render_set_uniform("uProjMatrixInv", matrix_inverse(proj_matrix))
	render_set_uniform_vec2("uScreenSize", render_width, render_height)
	render_set_uniform("uViewMatrixInv", matrix_inverse(view_matrix))
	
	// Reflections
	render_set_uniform_color("uSkyColor", app.background_sky_color_final, 1)
	render_set_uniform_color("uFogColor", app.background_fog_color_final, 1)
	render_set_uniform("uFadeAmount", render_raytraced ? app.project_render_rt_reflections_fade : app.project_render_reflections_fade_amount)
	render_set_uniform("uGamma", render_gamma)
	
	// Indirect
	render_set_uniform("uIndirectStength", render_raytraced ? app.project_render_rt_indirect_strength : app.project_render_indirect_strength)
}
