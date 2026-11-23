/// project_reset_render()

function project_reset_render()
{
	project_render_samples = 24
	project_render_distance = 30000
	
	project_render_ssao = true
	project_render_ssao_radius = 12
	project_render_ssao_power = 1
	project_render_ssao_color = c_black
	
	project_render_shadows = true
	project_render_shadows_sun_buffer_size = 2048
	project_render_shadows_spot_buffer_size = 512
	project_render_shadows_point_buffer_size = 256
	project_render_shadows_transparent = false
	
	project_render_subsurface_samples = 7
	project_render_subsurface_highlight = .5
	project_render_subsurface_highlight_strength = 1
	
	project_render_indirect = true
	project_render_indirect_precision = .3
	project_render_indirect_blur_radius = 1
	project_render_indirect_strength = 1
	
	project_render_reflections = true
	project_render_reflections_precision = .3
	project_render_reflections_thickness = 1
	project_render_reflections_fade_amount = 1
	
	project_render_glow = true
	project_render_glow_radius = 1
	project_render_glow_intensity = 1
	project_render_glow_falloff = false
	project_render_glow_falloff_radius = 2
	project_render_glow_falloff_intensity = 1
	
	project_render_aa = true
	project_render_aa_power = 1
	
	project_render_texture_filtering = true
	project_render_transparent_block_texture_filtering = false
	project_render_texture_filtering_level = 1
	
	project_render_alpha_mode = e_alpha_mode.BLEND
	project_render_tonemapper = e_tonemapper.NONE
	project_render_exposure = 1
	project_render_gamma = 2.2
	project_render_material_maps = false
	
	project_bend_style = "blocky"
	project_render_opaque_leaves = false
	project_render_liquid_animation = true
	project_render_water_reflections = false
	
	project_render_block_emissive = 1
	project_render_block_subsurface = 8
	
	project_render_glint_speed = 1
	project_render_glint_strength = 1
	
	project_render_depth_map_near = 0
	project_render_depth_map_far = 1000
	project_render_depth_map_curve = 1
	project_render_depth_map_normal_detail = true
	project_render_depth_map_detail_depth = 0.1
	project_render_hdr_peak = 1000
	project_render_hdr_paper_white = 203
	project_render_ok_samples = 512
	project_render_ok_bounces = 6
	project_render_ok_light_samples = 1
	project_render_ok_paths = 1
	project_render_ok_clamp = 10
	project_render_ok_roulette = 3
	project_render_rt_hw_denoise = true
	project_render_rt_hw_denoise_size = 1
	project_render_time_limit = 0
	project_render_rt_sky_reflection = 1
	project_render_rt_clamp = 0
	
	project_render_rt_samples = 128
	project_render_rt_precision = 0.8
	project_render_rt_steps = 512
	project_render_rt_distance = 5000
	project_render_rt_thickness = 1
	project_render_rt_full_res = true
	project_render_rt_indirect = true
	project_render_rt_indirect_strength = 1
	project_render_rt_sky_light = 0
	project_render_rt_denoise = 1
	project_render_rt_reflections = true
	project_render_rt_reflections_fade = 0.5
	project_render_rt_hardware = true
	project_render_rt_bounces = 2
	project_render_rt_reflection_bounces = 1
	project_render_rt_ray_offset = 0.05
	project_render_rt_alpha_cutout = true
	project_render_rt_shadows = true
	project_render_rt_sun_softness = 1
	project_render_rt_light_softness = 1
	project_render_rt_ambient = 1
	project_render_rt_emissive = 1
	project_render_rt_bounce_lights = true
	project_render_rt_reflection_strength = 1
	project_render_rt_roughness_cutoff = 0.9
	project_render_rt_specular = true
	project_render_rt_tinted_shadows = true
	project_render_rt_tint_strength = 2
	project_render_rt_bounce_saturation = 1.5
	project_render_pbr_normal_maps = true
	project_render_pbr_normal_strength = 1
	project_render_pbr_parallax = false
	project_render_pbr_parallax_depth = .25
	project_render_pbr_parallax_shadow = true
	project_render_pbr_pack_maps = true
	project_render_pbr_roughness = 1
	project_render_pbr_metallic = 1
	project_render_pbr_reflectivity = 1
	project_render_pbr_texture_ao = true
	project_render_pbr_ao_strength = 1
	project_render_depth_map_near_white = true
	
	texture_set_mipmap_level(project_render_texture_filtering_level)
	render_generate_dof_samples(0, 0, 0)
	render_samples = -1
	render_samples_clear = true
	
	// Update bend meshes
	with (obj_timeline)
	{
		bend_rot_last = vec3(0)
		tl_update_model_shape_bend()
	}
}