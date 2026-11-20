/// draw_badge(text, x, y, [disabled])
/// @arg text
/// @arg x
/// @arg y
/// @arg [disabled]
/// @desc Draws a small rounded accent badge (e.g. "DEPTH") with its left edge at x, vertically centered on y. Returns the width.

function draw_badge(text, xx, yy, disabled = false)
{
	var wid, hei, color, alpha;

	wid = badge_width(text)
	hei = 14
	xx = floor(xx)
	yy = floor(yy - hei / 2)

	color = (disabled ? c_text_tertiary : c_accent)
	alpha = (disabled ? a_text_tertiary : a_accent)

	draw_box_rounded(xx, yy, wid, hei, color, .15 * alpha)
	draw_label(text, xx + wid / 2, yy + hei / 2, fa_center, fa_middle, color, alpha, font_subheading)

	draw_set_font(font_label)

	return wid
}
