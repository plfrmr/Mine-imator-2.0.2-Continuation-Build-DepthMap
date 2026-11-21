/// surface_set_hdr(surface, hdr, depth)
/// @arg surface
/// @arg hdr
/// @arg depth
/// @desc Returns the surface with floating point (hdr) or 8-bit colors, recreating it (same size) if the format differs.
///		  A missing surface is created at the render size when hdr is requested.

function surface_set_hdr(surf, hdr, depth)
{
	if (!is_cpp())
		return surf

	if (surface_exists(surf))
	{
		if (surface_is_hdr(surf) = hdr)
			return surf

		var w, h;
		w = surface_get_width(surf)
		h = surface_get_height(surf)
		surface_free(surf)
		return surface_create_ext2(w, h, depth, hdr)
	}

	if (hdr)
		return surface_create_ext2(max(1, render_width), max(1, render_height), depth, true)

	return surf
}
