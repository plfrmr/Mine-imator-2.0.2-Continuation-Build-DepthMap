/// hdr_tonemap_scale(tonemapper, headroom)
/// @arg tonemapper
/// @arg headroom
/// @desc Input scale for the HDR10 tone curve (headroom * curve(color * scale / headroom)), chosen so mid gray stays as bright
///		  as with the normal (SDR) curve. Only highlights get brighter.

function hdr_tonemap_scale(tonemapper, headroom)
{
	if (tonemapper = 0 || headroom <= 1)
		return 1

	var target, lo, hi, mid;
	target = hdr_tonemap_curve(tonemapper, 0.18) / headroom
	lo = 0
	hi = 0.18

	repeat (40)
	{
		mid = (lo + hi) / 2
		if (hdr_tonemap_curve(tonemapper, mid) < target)
			lo = mid
		else
			hi = mid
	}

	return ((lo + hi) / 2) * headroom / 0.18
}

/// hdr_tonemap_curve(tonemapper, value)
/// @desc The tone curve of shader_tonemap for gray (1 = Reinhard, 2 = ACES fit).
function hdr_tonemap_curve(tonemapper, v)
{
	if (tonemapper = 1)
		return v / (1 + v)

	var a, b;
	a = v * (v + 0.0245786) - 0.000090537
	b = v * (0.983729 * v + 0.4329510) + 0.238081
	return a / b
}
