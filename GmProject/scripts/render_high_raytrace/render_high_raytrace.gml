/// render_high_raytrace()
/// @desc Traces the scene with hardware ray tracing (RT cores) into the light and specular buffers.
///		  Returns false if that isn't possible, then the regular shadow passes are used.

function render_high_raytrace()
{
	render_surface_shadows = surface_require(render_surface_shadows, render_width, render_height, false, true)
	render_surface_specular = surface_require(render_surface_specular, render_width, render_height, false, true)

	// Camera of the G-buffer
	rt_set_camera(matrix_inverse(view_matrix), matrix_inverse(proj_matrix), depth_near, depth_far, cam_from[X], cam_from[Y], cam_from[Z])

	// Sun
	rt_light_clear()

	if (background_sunlight_color_final != c_black)
	{
		var sun = background_sunlight_color_final;
		rt_light_add(0, 0, 0, 0, background_sun_direction[X], background_sun_direction[Y], background_sun_direction[Z],
					 color_get_red(sun) / 255, color_get_green(sun) / 255, color_get_blue(sun) / 255, background_sunlight_strength,
					 0, 1, 0, 0, 0, 1, true)
	}

	// Point and spot lights
	with (obj_timeline)
	{
		if (type != e_tl_type.POINT_LIGHT && type != e_tl_type.SPOT_LIGHT)
			continue

		if (!value_inherit[e_value.VISIBLE] || hide || !tl_get_visible())
			continue

		var spot, dir, col;
		spot = (type = e_tl_type.SPOT_LIGHT)
		dir = vec3(0, 0, 0)
		col = value[e_value.LIGHT_COLOR]

		if (spot)
			dir = vec3_normalize(point3D_sub(point3D_mul_matrix(point3D(0.0001, 1, 0), matrix), world_pos))

		rt_light_add(spot ? 2 : 1, world_pos[X], world_pos[Y], world_pos[Z], dir[X], dir[Y], dir[Z],
					 color_get_red(col) / 255, color_get_green(col) / 255, color_get_blue(col) / 255, value[e_value.LIGHT_STRENGTH],
					 value[e_value.LIGHT_RANGE], value[e_value.LIGHT_FADE_SIZE], value[e_value.LIGHT_SIZE],
					 spot ? value[e_value.LIGHT_SPOT_RADIUS] : 90, spot ? value[e_value.LIGHT_SPOT_SHARPNESS] : 0,
					 value[e_value.LIGHT_SPECULAR_STRENGTH], spot || shadows)
	}

	// Settings
	var sky, ambient;
	sky = background_sky_color_final
	ambient = background_ambient_color_final

	rt_set_param("normalscale", is_cpp() ? normal_buffer_scale : 1)
	rt_set_param("gamma", render_gamma)
	rt_set_param("bounces", project_render_rt_indirect ? project_render_rt_bounces : 0)
	rt_set_param("reflectionbounces", project_render_rt_reflection_bounces)
	rt_set_param("indirect", project_render_rt_indirect)
	rt_set_param("reflections", render_rt_reflections)
	rt_set_param("specular", project_render_rt_specular)
	rt_set_param("shadows", project_render_rt_shadows)
	rt_set_param("tintedshadows", project_render_rt_tinted_shadows)
	rt_set_param("tintstrength", project_render_rt_tint_strength)
	rt_set_param("bouncesaturation", project_render_rt_bounce_saturation)
	rt_set_param("defaultemissive", project_render_block_emissive)
	rt_set_param("normalmaps", project_render_pbr_normal_maps)
	rt_set_param("normalstrength", project_render_pbr_normal_strength)
	rt_set_param("parallaxdepth", (project_render_pbr_parallax && !dev_mode_skip_tangents) ? project_render_pbr_parallax_depth : 0)
	rt_set_param("parallaxshadow", project_render_pbr_parallax_shadow)
	rt_set_param("aostrength", project_render_pbr_texture_ao ? project_render_pbr_ao_strength : 0)
	rt_set_param("alphacutout", project_render_rt_alpha_cutout)
	rt_set_param("bouncelights", project_render_rt_bounce_lights)
	rt_set_param("skyr", color_get_red(sky) / 255)
	rt_set_param("skyg", color_get_green(sky) / 255)
	rt_set_param("skyb", color_get_blue(sky) / 255)
	rt_set_param("skystrength", project_render_rt_sky_light)
	
	// Sky color at the horizon (fog and sunset glow): reflections blend from it to the sky color upwards, like the sky behind the scene
	var horizon = ((background_fog_show && background_fog_sky) ? background_fog_color_final : sky);
	rt_set_param("horizonr", color_get_red(horizon) / 255)
	rt_set_param("horizong", color_get_green(horizon) / 255)
	rt_set_param("horizonb", color_get_blue(horizon) / 255)
	rt_set_param("ambientr", color_get_red(ambient) / 255)
	rt_set_param("ambientg", color_get_green(ambient) / 255)
	rt_set_param("ambientb", color_get_blue(ambient) / 255)
	rt_set_param("ambientstrength", project_render_rt_ambient)
	rt_set_param("indirectstrength", project_render_rt_indirect_strength)
	rt_set_param("emissivestrength", project_render_rt_emissive)
	rt_set_param("reflectionstrength", project_render_rt_reflection_strength)
	rt_set_param("roughnesscutoff", project_render_rt_roughness_cutoff)
	rt_set_param("maxdistance", project_render_rt_distance)
	rt_set_param("rayoffset", project_render_rt_ray_offset)
	rt_set_param("sunsoftness", project_render_rt_sun_softness)
	rt_set_param("lightsoftness", project_render_rt_light_softness)
	rt_set_param("alphathreshold", 0.5)
	rt_set_param("specularstrength", 1)
	rt_set_param("jitterx", taa_jitter_matrix[12])
	rt_set_param("jittery", taa_jitter_matrix[13])

	// CUSTOM: sky in reflections, firefly clamp of Raytraced mode
	rt_set_param("skyreflection", project_render_rt_sky_reflection)
	rt_set_param("rtclamp", project_render_rt_clamp)
	rt_set_param("reflectionbump", project_render_rt_reflection_bump)
	
	// OVERKILL: path tracing with everything on
	rt_set_param("overkill", render_overkill)
	if (render_overkill)
	{
		rt_set_param("bounces", project_render_ok_bounces)
		rt_set_param("reflectionbounces", project_render_ok_bounces)
		rt_set_param("indirect", true)
		rt_set_param("reflections", true)
		rt_set_param("specular", true)
		rt_set_param("shadows", true)
		rt_set_param("tintedshadows", true)
		rt_set_param("bouncelights", true)
		rt_set_param("alphacutout", true)
		rt_set_param("roughnesscutoff", 1)
		rt_set_param("oklightsamples", project_render_ok_light_samples)
		rt_set_param("okpaths", project_render_ok_paths)
		rt_set_param("okclamp", project_render_ok_clamp)
		rt_set_param("okroulette", project_render_ok_roulette)
	}

	if (!rt_trace(render_surface_depth, render_surface_normal, render_surface_diffuse, render_surface_material, render_surface_emissive,
				  render_surface_shadows, render_surface_specular, render_sample_current))
		return false

	// Denoise (CUSTOM)
	if (project_render_rt_hw_denoise && project_render_rt_hw_denoise_size > 0)
		render_high_rt_denoise()

	// Render passes
	if (render_pass = e_render_pass.SHADOWS || render_pass = e_render_pass.INDIRECT || render_pass = e_render_pass.INDIRECT_SHADOWS)
		render_pass_surf = surface_duplicate(render_surface_shadows)

	if (render_pass = e_render_pass.REFLECTIONS)
		render_pass_surf = surface_duplicate(render_surface_specular)

	return true
}
