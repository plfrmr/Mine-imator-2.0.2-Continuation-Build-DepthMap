/// render_set_texture_height(texture)
/// @arg texture
/// @desc Sets the parallax height map (the normal map, height is in its alpha) of shaders that have a uTextureHeight sampler.

function render_set_texture_height(tex)
{
	var sampler = render_shader_obj.sampler_map[?"uTextureHeight"];
	
	if (is_undefined(sampler) || sampler < 0)
		return 0
	
	if (gpu_get_texfilter_ext(sampler) != shader_texture_filter_linear)
		gpu_set_texfilter_ext(sampler, shader_texture_filter_linear)
	
	if (shader_texture_surface)
	{
		if (surface_exists(tex))
			texture_set_stage(sampler, surface_get_texture(tex))
		else
			texture_set_stage(sampler, 0)
	}
	else
	{
		if (sprite_exists(tex))
			texture_set_stage(sampler, sprite_get_texture(tex, 0))
		else
			texture_set_stage(sampler, 0)
	}
	
	gpu_set_texrepeat_ext(sampler, true)
}