/// export_save_image(surface, filename)
/// @arg surface
/// @arg filename
/// @desc Saves an exported image or image sequence frame, as HDR10 (16-bit PQ PNG) when enabled.

function export_save_image(surf, fn)
{
	if (export_hdr10 && is_cpp())
		surface_save_hdr10(surf, fn, project_render_hdr_paper_white, project_render_hdr_peak)
	else
		surface_save_lib(surf, fn)
}
