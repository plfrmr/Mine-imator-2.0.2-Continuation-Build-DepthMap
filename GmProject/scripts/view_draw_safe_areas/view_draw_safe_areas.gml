/// view_draw_safe_areas(x, y, width, height)
/// @arg x
/// @arg y
/// @arg width
/// @arg height
/// @desc CUSTOM: draws safe area guides over a view, like on broadcast monitors: action safe (93%), title safe (90%) and a
///		  mark in the center.

function view_draw_safe_areas(xx, yy, w, h)
{
	var scale, bw, bh;
	for (var i = 0; i < 2; i++)
	{
		scale = (i = 0 ? 0.93 : 0.9)
		bw = round(w * scale)
		bh = round(h * scale)
		draw_box(xx + round((w - bw) / 2), yy + round((h - bh) / 2), bw, bh, true, c_white, (i = 0 ? .55 : .35))
	}

	var cx, cy;
	cx = round(xx + w / 2)
	cy = round(yy + h / 2)
	draw_line_ext(cx - 10, cy, cx + 10, cy, c_white, .6)
	draw_line_ext(cx, cy - 10, cx, cy + 10, c_white, .6)
}
