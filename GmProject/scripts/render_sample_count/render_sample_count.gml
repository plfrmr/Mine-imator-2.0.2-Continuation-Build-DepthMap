/// render_sample_count()
/// @desc Returns the number of samples to accumulate for the current high quality render.

function render_sample_count()
{
	return (render_raytraced ? app.project_render_rt_samples : app.project_render_samples)
}
