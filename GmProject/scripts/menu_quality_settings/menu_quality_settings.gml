/// menu_quality_settings()

function menu_quality_settings()
{
	var capwid, text;
	
	// Render pass preview
	draw_set_font(font_label)
	capwid = max(176, text_max_width("viewmodepass") + 16)
	text = text_get("viewmodepass" + render_pass_list[|project_render_pass]);
	
	tab_control_menu()
	draw_button_menu("viewmodepass", e_menu.LIST, dx, dy, dw, 24, project_render_pass, text, action_project_render_pass)
	tab_next()
	
	// Safe area guides and render time estimate (CUSTOM)
	var custombadge = text_get("rendercustombadge");
	capwid = max(capwid, 250)
	
	tab_control_switch()
	draw_switch("viewsafeareas", dx, dy, setting_view_safe_areas, action_setting_view_safe_areas, "viewsafeareastip", false, custombadge, "custom")
	tab_next()
	
	tab_control_switch()
	draw_switch("viewrendereta", dx, dy, setting_view_render_eta, action_setting_view_render_eta, "viewrenderetatip", false, custombadge, "custom")
	tab_next()
	
	settings_menu_w = (capwid + 24)
}
