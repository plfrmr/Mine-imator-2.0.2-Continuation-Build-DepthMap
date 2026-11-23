/// render_hdr_surfaces(hdr)
/// @arg hdr
/// @desc Switches the surfaces used after tone mapping (post effects, sample accumulation, result) between float and 8-bit.
///		  HDR10 exports need float so highlights above paper white survive until the image is encoded.

function render_hdr_surfaces(hdr)
{
	// The shared scratch surfaces switch per sample in render_high (8-bit for the scene passes, float after tone mapping)
	if (!hdr)
		render_hdr_scratch_surfaces(false)
	
	// The G-buffers (material, diffuse) stay 8-bit: their shaders can write NaN, which only 8-bit turns into 0.
	// The post effects use render_surface_hdr[3] and [4] instead of them (see render_high_get_apply_surf).
	render_surface_material = surface_set_hdr(render_surface_material, false, true)
	render_surface_diffuse = surface_set_hdr(render_surface_diffuse, false, true)
	
	// The sample sums are always float: in 8-bit they overflow after 255 bright samples, which dimmed long renders
	render_surface_sample_expo = surface_set_hdr(render_surface_sample_expo, true, false)
	render_surface_sample_dec = surface_set_hdr(render_surface_sample_dec, true, false)
	render_surface_sample_alpha = surface_set_hdr(render_surface_sample_alpha, true, false)

	if (hdr)
		render_target = surface_set_hdr(render_target, true, true)
}
