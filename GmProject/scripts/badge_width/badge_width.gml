/// badge_width(text)
/// @arg text
/// @desc Returns the width of a badge drawn with draw_badge, or 0 for an empty text.

function badge_width(text)
{
	if (text = "")
		return 0

	return string_width_font(text, font_subheading) + 10
}
