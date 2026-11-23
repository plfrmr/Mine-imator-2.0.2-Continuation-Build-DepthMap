/// view_quality_high(quality)
/// @arg quality
/// @desc Returns whether a view mode uses the high quality renderer (Render or Raytraced).

function view_quality_high(quality)
{
	return (quality = e_view_mode.RENDER || quality = e_view_mode.RAYTRACED || quality = e_view_mode.OVERKILL)
}
