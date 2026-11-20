/// view_set_quality(view, quality)
/// @arg view
/// @arg quality
/// @desc Sets the view mode of a view. Only one view can use a high quality mode (Render or Raytraced) at a time.

function view_set_quality(view, quality)
{
	if (view.quality != quality)
		render_samples = -1

	view.quality = quality

	if (!view_quality_high(quality))
		return 0

	if (view = view_main && view_quality_high(view_second.quality))
		view_second.quality = e_view_mode.SHADED

	if (view = view_second && view_quality_high(view_main.quality))
		view_main.quality = e_view_mode.SHADED
}
