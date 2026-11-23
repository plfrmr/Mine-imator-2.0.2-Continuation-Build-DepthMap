/// popup_exportmodel_draw()
/// @desc CUSTOM: options for exporting a Minecraft JSON model.

function popup_exportmodel_draw()
{
	var custombadge = text_get("rendercustombadge");

	// Only the selected objects
	tab_control_switch()
	draw_switch("exportmodelselected", dx, dy, popup.selected_only, action_toolbar_exportmodel_selected, "exportmodelselectedtip", false, custombadge, "custom")
	tab_next()

	// Size in blocks
	tab_control_dragger()
	draw_dragger("exportmodelsize", dx, dy, dragger_width, popup.size_blocks, .01, .1, 3, 1, .1, popup.tbx_size, action_toolbar_exportmodel_size, null, true, false, "exportmodelsizetip", custombadge, "custom")
	tab_next()

	// Free rotation (newer Minecraft) or classic 22.5 degree steps
	tab_control_switch()
	draw_switch("exportmodelfreerotation", dx, dy, popup.free_rotation, action_toolbar_exportmodel_free_rotation, "exportmodelfreerotationtip", false, custombadge, "custom")
	tab_next()

	// Ready to use resource pack
	tab_control_switch()
	draw_switch("exportmodelresourcepack", dx, dy, popup.resource_pack, action_toolbar_exportmodel_resource_pack, "exportmodelresourcepacktip", false, custombadge, "custom")
	tab_next()

	// Save
	tab_control_button_label()
	draw_button_label("exportmodelsave", dx + dw, dy, null, icons.SAVE, e_button.PRIMARY, action_toolbar_exportmodel_save, e_anchor.RIGHT)
	tab_next()
}
