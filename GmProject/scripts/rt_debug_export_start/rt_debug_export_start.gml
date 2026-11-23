/// rt_debug_export_start()
/// @desc Developer: starts the export asked for in Data/rtdebug_open.txt ("hdrimage|file", "sdrimage|file" or "hdrmovie|file"),
///		  raytraced (or in Render mode with a "render" prefix, like "rendersdrimage|file"), once nothing is loading anymore.
///		  Used to test exports without the save dialog.

function rt_debug_export_start()
{
	if (rt_debug_export = "")
		return 0
	
	// Wait until 10 seconds after loading is done, so timelines have switched to the loaded resources
	if (window_state != "" || ds_priority_size(load_queue) > 0)
	{
		rt_debug_export_time = max(rt_debug_export_time, current_time + 10000)
		return 0
	}
	
	if (current_time < rt_debug_export_time)
		return 0

	var mode = rt_debug_export;
	rt_debug_export = ""
	var raytraced = (string_copy(mode, 1, 6) != "render");
	if (!raytraced)
		mode = string_delete(mode, 1, 6)
	var overkill = (string_copy(mode, 1, 2) = "ok"); // "okimage|file", "okhdrmovie|file"...: OVERKILL
	if (overkill)
		mode = string_delete(mode, 1, 2)
	export_filename = rt_debug_export_file
	log("Developer export", mode, export_filename)

	// "model|file.json": Minecraft model export (resource pack), "modelflat|file.json": just the JSON and PNG
	if (string_copy(mode, 1, 5) = "model")
	{
		popup_exportmodel.resource_pack = (mode != "modelflat")
		popup_exportmodel.free_rotation = (mode != "modelclassic") // Classic 22.5/45 degree rotations

		// "modelobjects|file.json": only characters (and their body parts), through Only selected objects
		popup_exportmodel.selected_only = (mode = "modelobjects")
		if (mode = "modelobjects")
			with (obj_timeline)
				selected = (type = e_tl_type.CHARACTER || type = e_tl_type.BODYPART)

		export_model(export_filename)
		return 0
	}

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
		popup_exportmovie.raytraced = raytraced
		exportmovie_marker_previous = timeline_marker
		exportmovie_format = "mp4"
		exportmovie_framespersecond = popup_exportmovie.framespersecond
		exportmovie_high_quality = true
		exportmovie_raytraced = raytraced
		popup_exportmovie.overkill = overkill
		exportmovie_overkill = overkill
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
		popup_exportimage.raytraced = raytraced
		popup_exportimage.overkill = overkill
		render_background = true
		window_state = "export_image"
	}

	view_main.quality = e_view_mode.SHADED
}
