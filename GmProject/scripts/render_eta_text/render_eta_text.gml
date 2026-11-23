/// render_eta_text(seconds)
/// @arg seconds
/// @desc CUSTOM: formats the time left of a render ("12 s", "3:05").

function render_eta_text(secs)
{
	secs = max(0, ceil(secs))
	if (secs < 60)
		return string(secs) + " s"

	var minutes = secs div 60;
	var rest = secs mod 60;
	return string(minutes) + ":" + (rest < 10 ? "0" : "") + string(rest)
}
