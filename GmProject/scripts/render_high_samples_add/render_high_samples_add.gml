/// render_high_samples_add()

function render_high_samples_add()
{
	var expsurf, decsurf, alphasurf;
	render_surface_sample_expo = surface_require(render_surface_sample_expo, render_width, render_height, false)
	render_surface_sample_dec = surface_require(render_surface_sample_dec, render_width, render_height, false)
	// Float copies: the running sums outgrow 8-bit after 255 bright samples (the image then dimmed as samples went on)
	render_surface_hdr[6] = surface_require(render_surface_hdr[6], render_width, render_height, false, is_cpp())
	render_surface_hdr[7] = surface_require(render_surface_hdr[7], render_width, render_height, false, is_cpp())
	expsurf = render_surface_hdr[6]
	decsurf = render_surface_hdr[7]
	alphasurf = null
	
	if (!render_background)
	{
		render_surface_sample_alpha = surface_require(render_surface_sample_alpha, render_width, render_height, false)
		render_surface_hdr[8] = surface_require(render_surface_hdr[8], render_width, render_height, false, is_cpp())
		alphasurf = render_surface_hdr[8]
	}
	
	// Draw temporary surfaces
	surface_set_target_ext(0, expsurf)
	surface_set_target_ext(1, decsurf)
	
	if (!render_background)
		surface_set_target_ext(2, alphasurf)
		
	{
		draw_clear_alpha(c_black, 0)
	}
	surface_reset_target()
	
	if (render_sample_current != 0 && !render_samples_clear)
	{
		surface_copy(expsurf, 0, 0, render_surface_sample_expo)
		surface_copy(decsurf, 0, 0, render_surface_sample_dec)
		
		if (!render_background)
			surface_copy(alphasurf, 0, 0, render_surface_sample_alpha)
	}
	
	// Add sample to buffer
	surface_set_target_ext(0, render_surface_sample_expo)
	surface_set_target_ext(1, render_surface_sample_dec)
	
	if (!render_background)
		surface_set_target_ext(2, render_surface_sample_alpha)
	
	{
		draw_clear_alpha(c_black, 0)
		
		render_shader_obj = shader_map[?shader_high_samples_add]
		with (render_shader_obj)
		{
			shader_set(shader)
			shader_high_samples_add_set(expsurf, decsurf, alphasurf, render_target)
		}
		draw_blank(0, 0, render_width, render_height)
		with (render_shader_obj)
			shader_clear()
	}
	surface_reset_target()
}