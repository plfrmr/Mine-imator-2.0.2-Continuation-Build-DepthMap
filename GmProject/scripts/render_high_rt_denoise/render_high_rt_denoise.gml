/// render_high_rt_denoise()
/// @desc CUSTOM: smooths the noise of ray traced light (Raytraced and OVERKILL modes) with a blur that stops at edges
///		  (depth and normals). The blur shrinks as samples add up, so finished renders stay sharp.

function render_high_rt_denoise()
{
	render_surface_hdr[5] = surface_require(render_surface_hdr[5], render_width, render_height, false, true)

	surface_set_target(render_surface_hdr[5])
	{
		gpu_set_blendmode_ext(bm_one, bm_zero)
		draw_clear_alpha(c_black, 0)

		render_shader_obj = shader_map[?shader_high_indirect_blur]
		with (render_shader_obj)
		{
			shader_set(shader)
			shader_high_indirect_blur_set(app.project_render_rt_hw_denoise_size)
		}

		draw_surface_exists(render_surface_shadows, 0, 0)

		with (render_shader_obj)
			shader_clear()

		gpu_set_blendmode(bm_normal)
	}
	surface_reset_target()

	surface_set_target(render_surface_shadows)
	{
		gpu_set_blendmode_ext(bm_one, bm_zero)
		draw_surface_exists(render_surface_hdr[5], 0, 0)
		gpu_set_blendmode(bm_normal)
	}
	surface_reset_target()
}
