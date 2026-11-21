/// rt_debug_export_start()
/// @desc Developer: starts the export asked for in Data/rtdebug_open.txt ("hdrimage|file", "sdrimage|file" or "hdrmovie|file"),
///		  raytraced, once nothing is loading anymore. Used to test exports without the save dialog.

function rt_debug_export_start()
{
	if (rt_debug_export = "" || window_state != "" || ds_priority_size(load_queue) > 0 || current_time < rt_debug_export_time)
		return 0

	var mode = rt_debug_export;
	rt_debug_export = ""
	export_filename = rt_debug_export_file
	log("Developer export", mode, export_filename)

	render_hidden = false
	render_watermark = false
	export_hdr10 = (string_copy(mode, 1, 3) = "hdr")
	exportmovie_frame = 0
	export_sample = 0
	exportmovie_start = current_time
	render_samples = -1

	if (string_pos("movie", mode) > 0)
	{
		popup_exportmovie.high_quality = true
		popup_exportmovie.raytraced = true
		exportmovie_marker_previous = timeline_marker
		exportmovie_format = "mp4"
		exportmovie_framespersecond = popup_exportmovie.framespersecond
		exportmovie_high_quality = true
		exportmovie_raytraced = true
		exportmovie_current_sound = null
		exportmovie_marker_start = 0
		exportmovie_marker_end = timeline_length

		movie_set(project_video_width, project_video_height, popup_exportmovie.bit_rate, exportmovie_framespersecond, false)
		movie_set_hdr(export_hdr10, project_render_hdr_paper_white, project_render_hdr_peak)
		if (movie_start(export_filename, "mp4") < 0)
		{
			log("Developer export: movie_start failed")
			return 0
		}

		render_background = true
		window_state = "export_movie"
		timeline_marker = exportmovie_marker_start
		action_tl_play_start()
	}
	else
	{
		popup_exportimage.high_quality = true
		popup_exportimage.raytraced = true
		render_background = true
		window_state = "export_image"
	}

	view_main.quality = e_view_mode.SHADED
}
