/// render_high_depth_map(depthsurf)
/// @arg depthsurf
/// @desc Converts the packed depth buffer into a new black and white depth map surface and returns it.

function render_high_depth_map(depthsurf)
{
	var surf = surface_create(render_width, render_height);
	
	surface_set_target(surf)
	{
		gpu_set_blendmode_ext(bm_one, bm_zero)
		draw_clear_alpha(c_black, 1)
		
		render_shader_obj = shader_map[?shader_high_depth_map]
		with (render_shader_obj)
		{
			shader_set(shader)
			shader_high_depth_map_set(depthsurf)
		}
		
		draw_surface_exists(depthsurf, 0, 0)
		
		with (render_shader_obj)
			shader_clear()
		
		gpu_set_blendmode(bm_normal)
	}
	surface_reset_target()
	
	return surf
}
