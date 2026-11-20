/// badge_width(text, [style])
/// @arg text
/// @arg [style]
/// @desc Returns the width of a badge drawn with draw_badge, or 0 for an empty text.

function badge_width(text, style = "")
{
	if (text = "")
		return 0

	// The fire style has a flame icon in front of the text
	return string_width_font(text, font_subheading) + 10 + (style = "fire" ? 12 : 0)
}
