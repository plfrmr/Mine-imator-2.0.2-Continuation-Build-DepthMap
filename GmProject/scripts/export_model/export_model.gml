/// export_model(filename)
/// @arg filename
/// @desc CUSTOM: exports the scene (or the selected objects) as a Minecraft JSON model with its texture. The objects are drawn
///		  once while every mesh is captured (without the sky and ground), then model_export_json turns the faces into model
///		  elements and bakes their pixels into one texture.

function export_model(fn)
{
	var folder, name, surf, result;
	folder = filename_dir(fn)
	name = filename_name(filename_new_ext(fn, ""))
	log("Export model", fn)

	// Draw the objects once while capturing
	render_raytraced = false
	render_overkill = false
	render_quality = e_view_mode.SHADED
	surf = surface_create(16, 16)
	render_start(surf, null, 16, 16)

	if (popup_exportmodel.selected_only)
	{
		with (obj_timeline)
			if (!selected && !parent_is_selected)
				render_visible = false
	}

	surface_set_target(surf)
	{
		draw_clear_alpha(c_black, 0)
		model_capture_begin()
		render_world_start()
		render_world(e_render_mode.COLOR_FOG_LIGHTS)
		render_world_done()
		model_capture_end()
	}
	surface_reset_target()

	surf = render_done()
	surface_free(surf)

	// Write the model
	result = model_export_json(folder, name, "mineimator", popup_exportmodel.size_blocks, popup_exportmodel.free_rotation, popup_exportmodel.resource_pack)
	log("Export model result", result)

	if (string_copy(result, 1, 6) = "error:")
	{
		toast_new(e_toast.NEGATIVE, text_get("alertexportmodelerror", string_delete(result, 1, 7)))
		return 0
	}

	// The summary starts with the number of faces; Minecraft slows down with many thousands of model elements
	var faces = real(string_digits(string_copy(result, 1, string_pos(" ", result))));
	toast_new(faces > 3000 ? e_toast.WARNING : e_toast.POSITIVE, text_get(faces > 3000 ? "alertexportmodelmany" : "alertexportmodel", string(faces)))
	toast_add_action("alertexportmodelfolder", popup_open_url, folder)
	toast_last.dismiss_time = 10
}
