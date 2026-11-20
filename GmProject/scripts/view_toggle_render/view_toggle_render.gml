/// view_toggle_render()

function view_toggle_render()
{
	if (view_second.show)
	{
		if (view_quality_high(view_second.quality))
		{
			view_second.quality = e_view_mode.SHADED
			render_free()

			return 0
		}
		else
			view_second.quality = e_view_mode.RENDER

		if (view_quality_high(view_main.quality))
			view_main.quality = e_view_mode.SHADED
	}
	else
	{
		if (view_quality_high(view_main.quality))
		{
			view_main.quality = e_view_mode.SHADED
			render_free()

			return 0
		}
		else
			view_main.quality = e_view_mode.RENDER
	}
}
