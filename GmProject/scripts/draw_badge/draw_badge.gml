/// draw_badge(text, x, y, [disabled, [style]])
/// @arg text
/// @arg x
/// @arg y
/// @arg [disabled
/// @arg [style]]
/// @desc Draws a small rounded badge (e.g. "DEPTH") with its left edge at x, vertically centered on y. Returns the width.
///		  Styles: "" = accent colored pill, "fire" = animated flaming pill with a flame icon (e.g. "RAYTRACING"),
///		  "fire_small" = the same without the icon, for tight rows.

function draw_badge(text, xx, yy, disabled = false, style = "")
{
	var wid, hei;

	wid = badge_width(text, style)
	hei = 14
	xx = floor(xx)
	yy = floor(yy - hei / 2)

	if ((style = "fire" || style = "fire_small") && !disabled)
	{
		draw_badge_fire(text, xx, yy, wid, hei, style = "fire")
		draw_set_font(font_label)
		return wid
	}

	var color, alpha;
	color = (disabled ? c_text_tertiary : c_accent)
	alpha = (disabled ? a_text_tertiary : a_accent)

	draw_box_rounded(xx, yy, wid, hei, color, .15 * alpha)
	draw_label(text, xx + wid / 2, yy + hei / 2, fa_center, fa_middle, color, alpha, font_subheading)

	draw_set_font(font_label)

	return wid
}

/// draw_badge_fire(text, x, y, width, height, icon)
/// @desc Draws the flaming badge style: hot gradient pill, flickering flames on top, a sweeping heat shimmer and a flame icon.
function draw_badge_fire(text, xx, yy, wid, hei, icon)
{
	var t, colyellow, colorange, colred, coldeep;
	t = (app.setting_reduced_motion ? 0 : current_time / 1000)
	colyellow = make_color_rgb(255, 214, 92)
	colorange = make_color_rgb(255, 136, 32)
	colred = make_color_rgb(232, 52, 28)
	coldeep = make_color_rgb(150, 24, 16)

	// Flames rising from the top edge (drawn first so their bases tuck behind the pill)
	var flames = 5;
	for (var i = 0; i < flames; i++)
	{
		var fx, fw, fh, sway;
		fx = xx + 6 + (wid - 12) * (i / (flames - 1))
		fw = 3 + (i mod 2)
		fh = 4 + 2.5 * (0.5 + 0.5 * sin(t * 9 + i * 1.9)) + 1.5 * (0.5 + 0.5 * sin(t * 15.3 + i * 4.1))
		sway = 1.2 * sin(t * 6 + i * 2.7)

		draw_primitive_begin(pr_trianglelist)
		draw_vertex_color(fx - fw, yy + 3, colred, 1)
		draw_vertex_color(fx + fw, yy + 3, colred, 1)
		draw_vertex_color(fx + sway, yy + 3 - fh, colyellow, 0.15)
		draw_primitive_end()

		// Hot inner core
		draw_primitive_begin(pr_trianglelist)
		draw_vertex_color(fx - fw * 0.5, yy + 3, colorange, 1)
		draw_vertex_color(fx + fw * 0.5, yy + 3, colorange, 1)
		draw_vertex_color(fx + sway * 0.6, yy + 3 - fh * 0.6, colyellow, 0.6)
		draw_primitive_end()
	}

	// Pill: rounded caps plus a yellow-orange to red gradient body
	draw_box_rounded(xx, yy, wid, hei, colred, 1)
	draw_box_rounded(xx, yy, 6, hei, colorange, 1, true, false, false, true)

	draw_primitive_begin(pr_trianglefan)
	draw_vertex_color(xx + 3, yy, colorange, 1)
	draw_vertex_color(xx + wid - 3, yy, colred, 1)
	draw_vertex_color(xx + wid - 3, yy + hei, coldeep, 1)
	draw_vertex_color(xx + 3, yy + hei, colorange, 1)
	draw_primitive_end()

	// Heat shimmer sweeping across
	if (!app.setting_reduced_motion)
	{
		var sx, sw, sl, sr, period;
		sw = 10
		period = wid + sw * 2
		sx = xx - sw + (t * 40 - floor(t * 40 / period) * period)
		sl = clamp(sx, xx + 2, xx + wid - 2)
		sr = clamp(sx + sw, xx + 2, xx + wid - 2)

		if (sr > sl)
		{
			draw_primitive_begin(pr_trianglefan)
			draw_vertex_color(sl, yy + 1, c_white, 0)
			draw_vertex_color((sl + sr) / 2, yy + 1, c_white, 0.35)
			draw_vertex_color(sr, yy + 1, c_white, 0)
			draw_vertex_color(sr, yy + hei - 1, c_white, 0)
			draw_vertex_color((sl + sr) / 2, yy + hei - 1, c_white, 0.35)
			draw_vertex_color(sl, yy + hei - 1, c_white, 0)
			draw_primitive_end()
		}
	}

	// Flame icon and text with a dark shadow for contrast
	var textx = xx + wid / 2;
	if (icon)
	{
		draw_image(spr_icons, icons.FIRE, xx + 8, yy + hei / 2, 0.55, 0.55, colyellow, 1)
		textx = xx + 15 + (wid - 15) / 2
	}
	
	draw_label(text, textx + 1, yy + hei / 2 + 1, fa_center, fa_middle, coldeep, 0.6, font_subheading)
	draw_label(text, textx, yy + hei / 2, fa_center, fa_middle, c_white, 1, font_subheading)
}
