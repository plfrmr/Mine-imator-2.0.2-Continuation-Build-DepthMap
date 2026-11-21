/// render_hdr_scratch_surfaces(hdr)
/// @arg hdr
/// @desc Switches the shared scratch surfaces (render_surface[0-2]) between 8-bit and float. The scene passes store data in them
///		  that relies on 8-bit clamping, the effects after tone mapping need float in HDR10 exports.

function render_hdr_scratch_surfaces(hdr)
{
	render_surface[0] = surface_set_hdr(render_surface[0], hdr, true)
	render_surface[1] = surface_set_hdr(render_surface[1], hdr, true)
	render_surface[2] = surface_set_hdr(render_surface[2], hdr, true)
}
