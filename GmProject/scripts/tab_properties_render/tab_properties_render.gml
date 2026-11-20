/// tab_properties_render()

function tab_properties_render()
{
	var text;

	// Graphics card (an app setting stored outside the project, applied when Mine-imator starts)
	tab_control_menu()
	draw_button_menu("rendergpu", e_menu.LIST, dx, dy, dw, 24, render_gpu_preferred, gpu_adapter_display_name(render_gpu_preferred), action_setting_render_gpu)
	tab_next()

	if (render_gpu_preferred != render_gpu_startup)
		draw_tooltip_label("rendergpurestart", icons.INFO, e_toast.INFO)

	// Render setings
	if (project_render_settings = "")
		text = text_get("projectrendersettingscustom")
	else if (text_exists("projectrendersettings" + project_render_settings))
		text = text_get("projectrendersettings" + project_render_settings)
	else
		text = filename_name(project_render_settings)
	
	tab_control_menu()
	draw_button_menu("projectrendersettings", e_menu.LIST, dx, dy, dw, 24, project_render_settings, text, action_project_render_settings)
	tab_next()
	
	if (project_render_settings != "")
		return 0
	
	dy += 8
	
	// Render distance
	tab_control_dragger()
	draw_dragger("renderdistance", dx, dy, dragger_width, project_render_distance, 1, 1000, 100000, 30000, 1, tab.render.tbx_render_distance, action_project_render_distance, null, true, false, "renderdistancetip")
	tab_next()
	
	// Render samples
	tab_control_dragger()
	draw_dragger("rendersamples", dx, dy, dragger_width, project_render_samples, .5, 1, 256, 24, 1, tab.render.tbx_samples, action_project_render_samples)
	tab_next()
	
	// SSAO
	tab_control_switch()
	draw_button_collapse("ssao", collapse_map[?"ssao"], action_project_render_ssao, project_render_ssao, "renderssao", "renderssaotip")
	tab_next()
	
	if (project_render_ssao && collapse_map[?"ssao"])
	{
		tab_collapse_start()
		
		tab_control_dragger()
		draw_dragger("renderssaoradius", dx, dy, dragger_width, project_render_ssao_radius, project_render_ssao_radius / 200, 0, 256, 12, 0, tab.render.tbx_ssao_radius, action_project_render_ssao_radius)
		tab_next()
		
		tab_control_dragger()
		draw_dragger("renderssaopower", dx, dy, dragger_width, round(project_render_ssao_power * 100), .5, 0, no_limit * 100, 100, 1, tab.render.tbx_ssao_power, action_project_render_ssao_power)
		tab_next()
		
		tab_control_color()
		draw_button_color("renderssaocolor", dx, dy, dw, project_render_ssao_color, c_black, false, action_project_render_ssao_color)
		tab_next()
		
		tab_collapse_end()
	}
	
	// Shadows
	tab_control_switch()
	draw_button_collapse("shadows", collapse_map[?"shadows"], action_project_render_shadows, project_render_shadows, "rendershadows")
	tab_next()
	
	if (project_render_shadows && collapse_map[?"shadows"])
	{
		tab_collapse_start()
		
		tab_control_menu()
		draw_button_menu("rendershadowssunbuffersize", e_menu.LIST, dx, dy, dw, 24, project_render_shadows_sun_buffer_size, text_get("rendershadowsbuffersize" + string(project_render_shadows_sun_buffer_size)) + " (" + string(project_render_shadows_sun_buffer_size) + "x" + string(project_render_shadows_sun_buffer_size) + ")", action_project_render_shadows_sun_buffer_size)
		tab_next()
		
		tab_control_menu()
		draw_button_menu("rendershadowsspotbuffersize", e_menu.LIST, dx, dy, dw, 24, project_render_shadows_spot_buffer_size, text_get("rendershadowsbuffersize" + string(project_render_shadows_spot_buffer_size)) + " (" + string(project_render_shadows_spot_buffer_size) + "x" + string(project_render_shadows_spot_buffer_size) + ")", action_project_render_shadows_spot_buffer_size)
		tab_next()
		
		tab_control_menu()
		draw_button_menu("rendershadowspointbuffersize", e_menu.LIST, dx, dy, dw, 24, project_render_shadows_point_buffer_size, text_get("rendershadowsbuffersize" + string(project_render_shadows_point_buffer_size)) + " (" + string(project_render_shadows_point_buffer_size) + "x" + string(project_render_shadows_point_buffer_size) + ")", action_project_render_shadows_point_buffer_size)
		tab_next()
		
		tab_control_switch()
		draw_switch("rendershadowstransparent", dx, dy, project_render_shadows_transparent, action_project_render_shadows_transparent)
		tab_next()
		
		tab_collapse_end()
	}
	
	// Subsurface scattering
	tab_control_switch()
	draw_button_collapse("subsurface", collapse_map[?"subsurface"], null, true, "rendersubsurfacescattering", "rendersubsurfacescatteringtip")
	tab_next()
	
	if (collapse_map[?"subsurface"])
	{
		tab_collapse_start()
		
		tab_control_meter()
		draw_meter("rendersubsurfacescatterquality", dx, dy, dw, project_render_subsurface_samples, 0, 32, 7, 1, tab.render.tbx_subsurface_samples, action_project_render_subsurface_samples)
		tab_next()
		
		tab_control_meter()
		draw_meter("rendersubsurfacescatterhighlight", dx, dy, dw, round(project_render_subsurface_highlight * 100), 0, 100, 50, 1, tab.render.tbx_subsurface_highlight, action_project_render_subsurface_highlight, "rendersubsurfacescatterhighlighttip")
		tab_next()
		
		tab_control_dragger()
		draw_dragger("rendersubsurfacescatterhighlightstrength", dx, dy, dragger_width, round(project_render_subsurface_highlight_strength * 100), .5, 0, no_limit, 100, 1, tab.render.tbx_subsurface_highlight_strength, action_project_render_subsurface_highlight_strength)
		tab_next()
		
		tab_collapse_end()
	}
	
	// Indirect lighting
	tab_control_switch()
	draw_button_collapse("indirect", collapse_map[?"indirect"], action_project_render_indirect, project_render_indirect, "renderindirect", "renderindirecttip")
	tab_next()
	
	if (project_render_indirect && collapse_map[?"indirect"])
	{
		tab_collapse_start()
		
		tab_control_meter()
		draw_meter("renderindirectprecision", dx, dy, dw, round(project_render_indirect_precision * 100), 0, 100, 30, 1, tab.render.tbx_indirect_precision, action_project_render_indirect_precision, "renderindirectprecisiontip")
		tab_next()
		
		tab_control_meter()
		draw_meter("renderindirectblurradius", dx, dy, dw, round(project_render_indirect_blur_radius * 100), 0, 500, 100, 1, tab.render.tbx_indirect_blur_radius, action_project_render_indirect_blur_radius)
		tab_next()
		
		tab_control_dragger()
		draw_dragger("renderindirectstrength", dx, dy, dragger_width, round(project_render_indirect_strength * 100), .5, 0, no_limit * 100, 100, 1, tab.render.tbx_indirect_strength, action_project_render_indirect_strength) 
		tab_next()
		
		tab_collapse_end()
	}
	
	// Reflections
	tab_control_switch()
	draw_button_collapse("reflections", collapse_map[?"reflections"], action_project_render_reflections, project_render_reflections, "renderreflections")
	tab_next()
	
	if (project_render_reflections && collapse_map[?"reflections"])
	{
		tab_collapse_start()
		
		tab_control_meter()
		draw_meter("renderreflectionsprecision", dx, dy, dw, round(project_render_reflections_precision * 100), 0, 100, 30, 1, tab.render.tbx_reflections_precision, action_project_render_reflections_precision, "renderreflectionsprecisiontip") 
		tab_next()
		
		tab_control_meter()
		draw_meter("renderreflectionsfadeamount", dx, dy, dw, round(project_render_reflections_fade_amount * 100), 0, 100, 50, 1, tab.render.tbx_reflections_fade_amount, action_project_render_reflections_fade_amount, "renderreflectionsfadeamounttip") 
		tab_next()
		
		tab_control_dragger()
		draw_dragger("renderreflectionsthickness", dx, dy, dragger_width, project_render_reflections_thickness, 1, .1, no_limit, 1, .1, tab.render.tbx_reflections_thickness, action_project_render_reflections_thickness, null, true, false, "renderreflectionsthicknesstip") 
		tab_next()
		
		tab_collapse_end()
	}
	
	// Glow
	tab_control_switch()
	draw_button_collapse("glow", collapse_map[?"glow"], action_project_render_glow, project_render_glow, "renderglow")
	tab_next()
	
	if (project_render_glow && collapse_map[?"glow"])
	{
		tab_collapse_start()
		
		tab_control_dragger()
		draw_dragger("renderglowradius", dx, dy, dragger_width, round(project_render_glow_radius * 100), .5, 0, no_limit * 100, 100, 1, tab.render.tbx_glow_radius, action_project_render_glow_radius)
		tab_next()
		
		tab_control_dragger()
		draw_dragger("renderglowintensity", dx, dy, dragger_width, round(project_render_glow_intensity * 100), .5, 0, no_limit * 100, 100, 1, tab.render.tbx_glow_intensity, action_project_render_glow_intensity)
		tab_next()
		
		tab_control_switch()
		draw_button_collapse("glow_falloff", collapse_map[?"glow_falloff"], action_project_render_glow_falloff, project_render_glow_falloff, "renderglowfalloff")
		tab_next()
		
		// Secondary glow
		if (project_render_glow_falloff && collapse_map[?"glow_falloff"])
		{
			tab_collapse_start()
			
			tab_control_dragger()
			draw_dragger("renderglowfalloffradius", dx, dy, dragger_width, round(project_render_glow_falloff_radius * 100), .5, 0, no_limit * 100, 200, 1, tab.render.tbx_glow_falloff_radius, action_project_render_glow_falloff_radius)
			tab_next()
			
			tab_control_dragger()
			draw_dragger("renderglowfalloffintensity", dx, dy, dragger_width, round(project_render_glow_falloff_intensity * 100), .5, 0, no_limit * 100, 100, 1, tab.render.tbx_glow_falloff_intensity, action_project_render_glow_falloff_intensity)
			tab_next()
			
			tab_collapse_end(false)
		}
		
		tab_collapse_end()
	}
	
	// AA
	tab_control_switch()
	draw_button_collapse("aa", collapse_map[?"aa"], action_project_render_aa, project_render_aa, "renderaa", "renderaatip")
	tab_next()
	
	if (project_render_aa && collapse_map[?"aa"])
	{
		tab_collapse_start()
		
		tab_control_meter()
		draw_meter("renderaapower", dx, dy, dw, round(project_render_aa_power * 100), 0, 300, 100, 1, tab.render.tbx_aa_power, action_project_render_aa_power)
		tab_next()
		
		tab_collapse_end()
	}
	
	// Texture filtering
	tab_control_switch()
	draw_button_collapse("texfilter", collapse_map[?"texfilter"], action_project_render_texture_filtering, project_render_texture_filtering, "rendertexturefiltering", "rendertexturefilteringtip")
	tab_next()
	
	if (project_render_texture_filtering && collapse_map[?"texfilter"])
	{
		tab_collapse_start()
		
		// Transparent block texture filtering
		tab_control_switch()
		draw_switch("rendertexturefilteringtransparentblocks", dx, dy, project_render_transparent_block_texture_filtering, action_project_render_transparent_block_texture_filtering)
		tab_next()
		
		// Texture filtering level
		tab_control_meter()
		draw_meter("rendertexturefilteringlevel", dx, dy, dw, project_render_texture_filtering_level, 0, 5, 1, 1, tab.render.tbx_texture_filtering_level, action_project_render_texture_filtering_level)
		tab_next()
		
		tab_collapse_end()
	}
	
	// Light management
	tab_control_switch()
	draw_button_collapse("light_management", collapse_map[?"light_management"], null, true, "renderlightmanagement")
	tab_next()
	
	if (collapse_map[?"light_management"])
	{
		tab_collapse_start()
		
		
		// Tonemapper
		switch (project_render_tonemapper)
		{
			case e_tonemapper.REINHARD:
				text = text_get("rendertonemapperreinhard")
				break;
			case e_tonemapper.ACES:
				text = text_get("rendertonemapperaces")
				break;
			default:
				text = text_get("rendertonemappernone")
				break;
		}
		
		tab_control_menu()
		draw_button_menu("rendertonemapper", e_menu.LIST, dx, dy, dw, 24, project_render_tonemapper, text, action_project_render_tonemapper)
		tab_next()
		
		// Exposure
		tab_control_dragger()
		draw_dragger("renderexposure", dx, dy, dragger_width, project_render_exposure, 0.01, 0, no_limit, 1, 0.01, tab.render.tbx_exposure, action_project_render_exposure)
		tab_next()
		
		// Gamma
		tab_control_dragger()
		draw_dragger("rendergamma", dx, dy, dragger_width, project_render_gamma, 0.01, 0, no_limit, 2.2, 0.01, tab.render.tbx_gamma, action_project_render_gamma)
		tab_next()
		
		tab_collapse_end()
	}
	
	// Models and scenery
	tab_control_switch()
	draw_button_collapse("models_scenery", collapse_map[?"models_scenery"], null, true, "rendermodelsscenery")
	tab_next()
	
	if (collapse_map[?"models_scenery"])
	{
		tab_collapse_start()
		
		// Bending style
		tab_control_togglebutton()
		togglebutton_add("renderbendstylerealistic", null, "realistic", project_bend_style = "realistic", action_project_bend_style)
		togglebutton_add("renderbendstyleblocky", null, "blocky", project_bend_style = "blocky", action_project_bend_style)
		draw_togglebutton("renderbendstyle", dx, dy)
		tab_next()
		
		// Opaque leaves
		tab_control_switch()
		draw_switch("renderopaqueleaves", dx, dy, project_render_opaque_leaves, action_project_render_opaque_leaves)
		tab_next()
		
		// Liquid waves
		tab_control_switch()
		draw_switch("renderliquidanimation", dx, dy, project_render_liquid_animation, action_project_render_liquid_animation)
		tab_next()
		
		// Water reflections
		tab_control_switch()
		draw_switch("renderwaterreflections", dx, dy, project_render_water_reflections, action_project_render_water_reflections, "renderwaterreflectionshelp")
		tab_next()
		
		tab_collapse_end()
	}
	
	// Glint settings
	tab_control_switch()
	draw_button_collapse("glint", collapse_map[?"glint"], null, true, "renderglint")
	tab_next()
	
	if (collapse_map[?"glint"])
	{
		tab_collapse_start()
		
		tab_control_dragger()
		draw_dragger("renderglintspeed", dx, dy, dragger_width, round(project_render_glint_speed * 100), 1, 0, no_limit, 100, 1, tab.render.tbx_glint_speed, action_project_render_glint_speed)
		tab_next()
	
		tab_control_dragger()
		draw_dragger("renderglintstrength", dx, dy, dragger_width, round(project_render_glint_strength * 100), 1, 0, no_limit, 100, 1, tab.render.tbx_glint_strength, action_project_render_glint_strength)
		tab_next()
		
		tab_collapse_end()
	}
	
	// Depth map pass (settings are marked with a badge, they only affect the Depth map render pass)
	var depthbadge = text_get("renderdepthbadge");

	tab_control_switch()
	draw_button_collapse("depth_map", collapse_map[?"depth_map"], null, true, "renderdepthmap", "renderdepthmaptip", depthbadge)
	tab_next()

	if (collapse_map[?"depth_map"])
	{
		tab_collapse_start()

		// Near distance
		tab_control_dragger()
		draw_dragger("renderdepthmapnear", dx, dy, dragger_width, project_render_depth_map_near, max(0.5, project_render_depth_map_near / 50), 0, no_limit, 0, 0, tab.render.tbx_depth_map_near, action_project_render_depth_map_near, null, true, false, "renderdepthmapneartip", depthbadge)
		tab_next()
		
		// Far distance
		tab_control_dragger()
		draw_dragger("renderdepthmapfar", dx, dy, dragger_width, project_render_depth_map_far, max(0.5, project_render_depth_map_far / 50), 0, no_limit, 1000, 0, tab.render.tbx_depth_map_far, action_project_render_depth_map_far, null, true, false, "renderdepthmapfartip", depthbadge)
		tab_next()
		
		// Curve
		tab_control_dragger()
		draw_dragger("renderdepthmapcurve", dx, dy, dragger_width, project_render_depth_map_curve, 0.01, 0.01, no_limit, 1, 0.01, tab.render.tbx_depth_map_curve, action_project_render_depth_map_curve, null, true, false, "renderdepthmapcurvetip", depthbadge)
		tab_next()
		
		// Near is white
		tab_control_switch()
		draw_switch("renderdepthmapnearwhite", dx, dy, project_render_depth_map_near_white, action_project_render_depth_map_near_white, "renderdepthmapnearwhitetip", false, depthbadge)
		tab_next()

		// Normal map detail (height maps of PBR packs)
		tab_control_switch()
		draw_button_collapse("depth_map_detail", collapse_map[?"depth_map_detail"], action_project_render_depth_map_normal_detail, project_render_depth_map_normal_detail, "renderdepthmapnormaldetail", "renderdepthmapnormaldetailtip", depthbadge)
		tab_next()

		if (project_render_depth_map_normal_detail && collapse_map[?"depth_map_detail"])
		{
			tab_collapse_start()

			tab_control_dragger()
			draw_dragger("renderdepthmapdetaildepth", dx, dy, dragger_width, round(project_render_depth_map_detail_depth * 1000) / 10, .1, 0, 100, 10, 0.1, tab.render.tbx_depth_map_detail_depth, action_project_render_depth_map_detail_depth, null, true, false, "renderdepthmapdetaildepthtip", depthbadge)
			tab_next()

			tab_collapse_end(false)
		}

tab_collapse_end()
	}
	
	// Raytracing (settings for the Raytraced view mode and raytraced exports)
	var rtbadge = text_get("renderraytracingbadge");
	
	tab_control_switch()
	draw_button_collapse("raytracing", collapse_map[?"raytracing"], null, true, "renderraytracing", "renderraytracingtip", rtbadge, "fire")
	tab_next()
	
	if (collapse_map[?"raytracing"])
	{
		tab_collapse_start()
		
		// Hardware ray tracing (RT cores) and its status
		tab_control_switch()
		draw_switch("renderrthardware", dx, dy, project_render_rt_hardware, action_project_render_rt_hardware, "renderrthardwaretip", false, rtbadge, "fire_small")
		tab_next()
		
		var hw = (project_render_rt_hardware && rt_supported());
		
		if (project_render_rt_hardware)
		{
			tab_control(18)
			draw_label(string_limit(text_get("renderrthardwarestatus", rt_status()), dw), dx, dy + 9, fa_left, fa_middle, hw ? c_text_secondary : setting_theme.toast_color[e_toast.WARNING], hw ? a_text_secondary : 1, font_caption)
			tab_next()
		}
		
		// Samples
		tab_control_dragger()
		draw_dragger("renderrtsamples", dx, dy, dragger_width, project_render_rt_samples, .5, 1, 4096, 128, 1, tab.render.tbx_rt_samples, action_project_render_rt_samples, null, true, false, "renderrtsamplestip", rtbadge, "fire_small")
		tab_next()
		
		if (hw)
		{
			tab_control_dragger()
			draw_dragger("renderrtbounces", dx, dy, dragger_width, project_render_rt_bounces, .1, 0, 16, 2, 1, tab.render.tbx_rt_bounces, action_project_render_rt_bounces, null, true, false, "renderrtbouncestip", rtbadge, "fire_small")
			tab_next()
			
			tab_control_dragger()
			draw_dragger("renderrtdistance", dx, dy, dragger_width, project_render_rt_distance, max(1, project_render_rt_distance / 100), 16, no_limit, 5000, 1, tab.render.tbx_rt_distance, action_project_render_rt_distance, null, true, false, "renderrtdistancetip", rtbadge, "fire_small")
			tab_next()
			
			tab_control_dragger()
			draw_dragger("renderrtrayoffset", dx, dy, dragger_width, project_render_rt_ray_offset, .005, .001, 16, .05, .001, tab.render.tbx_rt_ray_offset, action_project_render_rt_ray_offset, null, true, false, "renderrtrayoffsettip", rtbadge, "fire_small")
			tab_next()
			
			tab_control_switch()
			draw_switch("renderrtalphacutout", dx, dy, project_render_rt_alpha_cutout, action_project_render_rt_alpha_cutout, "renderrtalphacutouttip", false, rtbadge, "fire_small")
			tab_next()
			
			// Shadows
			tab_control_switch()
			draw_button_collapse("rt_shadows", collapse_map[?"rt_shadows"], action_project_render_rt_shadows, project_render_rt_shadows, "renderrtshadows", "renderrtshadowstip", rtbadge, "fire")
			tab_next()
			
			if (project_render_rt_shadows && collapse_map[?"rt_shadows"])
			{
				tab_collapse_start()
				
				tab_control_dragger()
				draw_dragger("renderrtsunsoftness", dx, dy, dragger_width, project_render_rt_sun_softness, .05, 0, 45, 1, .1, tab.render.tbx_rt_sun_softness, action_project_render_rt_sun_softness, null, true, false, "renderrtsunsoftnesstip", rtbadge, "fire_small")
				tab_next()
				
				tab_control_switch()
				draw_switch("renderrttintedshadows", dx, dy, project_render_rt_tinted_shadows, action_project_render_rt_tinted_shadows, "renderrttintedshadowstip", false, rtbadge, "fire_small")
				tab_next()
				
				if (project_render_rt_tinted_shadows)
				{
					tab_control_dragger()
					draw_dragger("renderrttintstrength", dx, dy, dragger_width, round(project_render_rt_tint_strength * 100), .5, 0, 1000, 200, 1, tab.render.tbx_rt_tint_strength, action_project_render_rt_tint_strength, null, true, false, "renderrttintstrengthtip", rtbadge, "fire_small")
					tab_next()
				}
				
				tab_control_dragger()
				draw_dragger("renderrtlightsoftness", dx, dy, dragger_width, round(project_render_rt_light_softness * 100), .5, 0, 1000, 100, 1, tab.render.tbx_rt_light_softness, action_project_render_rt_light_softness, null, true, false, "renderrtlightsoftnesstip", rtbadge, "fire_small")
				tab_next()
				
				tab_collapse_end(false)
			}
		}
		else
		{
			// Screen-space ray tracing
			tab_control_meter()
			draw_meter("renderrtprecision", dx, dy, dw, round(project_render_rt_precision * 100), 0, 100, 80, 1, tab.render.tbx_rt_precision, action_project_render_rt_precision, "renderrtprecisiontip", rtbadge, "fire_small")
			tab_next()
			
			tab_control_dragger()
			draw_dragger("renderrtsteps", dx, dy, dragger_width, project_render_rt_steps, 2, 16, 4096, 512, 1, tab.render.tbx_rt_steps, action_project_render_rt_steps, null, true, false, "renderrtstepstip", rtbadge, "fire_small")
			tab_next()
			
			tab_control_dragger()
			draw_dragger("renderrtdistance", dx, dy, dragger_width, project_render_rt_distance, max(1, project_render_rt_distance / 100), 16, no_limit, 5000, 1, tab.render.tbx_rt_distance, action_project_render_rt_distance, null, true, false, "renderrtdistancetip", rtbadge, "fire_small")
			tab_next()
			
			tab_control_dragger()
			draw_dragger("renderrtthickness", dx, dy, dragger_width, round(project_render_rt_thickness * 100), .5, 1, 1000, 100, 1, tab.render.tbx_rt_thickness, action_project_render_rt_thickness, null, true, false, "renderrtthicknesstip", rtbadge, "fire_small")
			tab_next()
			
			tab_control_switch()
			draw_switch("renderrtfullres", dx, dy, project_render_rt_full_res, action_project_render_rt_full_res, "renderrtfullrestip", false, rtbadge, "fire_small")
			tab_next()
			
		}
		
		// Bounce light
		tab_control_switch()
		draw_button_collapse("rt_indirect", collapse_map[?"rt_indirect"], action_project_render_rt_indirect, project_render_rt_indirect, "renderrtindirect", "renderrtindirecttip", rtbadge, "fire")
		tab_next()
		
		if (project_render_rt_indirect && collapse_map[?"rt_indirect"])
		{
			tab_collapse_start()
			
			tab_control_dragger()
			draw_dragger("renderrtindirectstrength", dx, dy, dragger_width, round(project_render_rt_indirect_strength * 100), .5, 0, no_limit * 100, 100, 1, tab.render.tbx_rt_indirect_strength, action_project_render_rt_indirect_strength, null, true, false, "", rtbadge, "fire_small")
			tab_next()
			
			tab_control_dragger()
			draw_dragger("renderrtbouncesaturation", dx, dy, dragger_width, round(project_render_rt_bounce_saturation * 100), .5, 0, 1000, 150, 1, tab.render.tbx_rt_bounce_saturation, action_project_render_rt_bounce_saturation, null, true, false, "renderrtbouncesaturationtip", rtbadge, "fire_small")
			tab_next()
			
			tab_control_meter()
			draw_meter("renderrtskylight", dx, dy, dw, round(project_render_rt_sky_light * 100), 0, 200, 0, 1, tab.render.tbx_rt_sky_light, action_project_render_rt_sky_light, "renderrtskylighttip", rtbadge, "fire_small")
			tab_next()
			
			if (hw)
			{
				tab_control_meter()
				draw_meter("renderrtambient", dx, dy, dw, round(project_render_rt_ambient * 100), 0, 200, 100, 1, tab.render.tbx_rt_ambient, action_project_render_rt_ambient, "renderrtambienttip", rtbadge, "fire_small")
				tab_next()
				
				tab_control_dragger()
				draw_dragger("renderrtemissive", dx, dy, dragger_width, round(project_render_rt_emissive * 100), .5, 0, no_limit * 100, 100, 1, tab.render.tbx_rt_emissive, action_project_render_rt_emissive, null, true, false, "renderrtemissivetip", rtbadge, "fire_small")
				tab_next()
				
				tab_control_switch()
				draw_switch("renderrtbouncelights", dx, dy, project_render_rt_bounce_lights, action_project_render_rt_bounce_lights, "renderrtbouncelightstip", false, rtbadge, "fire_small")
				tab_next()
				
			}
			else
			{
				tab_control_meter()
				draw_meter("renderrtdenoise", dx, dy, dw, round(project_render_rt_denoise * 100), 0, 500, 100, 1, tab.render.tbx_rt_denoise, action_project_render_rt_denoise, "renderrtdenoisetip", rtbadge, "fire_small")
				tab_next()
				
			}
			
			tab_collapse_end(false)
		}
		
		// Reflections
		tab_control_switch()
		draw_button_collapse("rt_reflections", collapse_map[?"rt_reflections"], action_project_render_rt_reflections, project_render_rt_reflections, "renderrtreflections", "renderrtreflectionstip", rtbadge, "fire")
		tab_next()
		
		if (project_render_rt_reflections && collapse_map[?"rt_reflections"])
		{
			tab_collapse_start()
			
			if (hw)
			{
				tab_control_dragger()
				draw_dragger("renderrtreflectionstrength", dx, dy, dragger_width, round(project_render_rt_reflection_strength * 100), .5, 0, no_limit * 100, 100, 1, tab.render.tbx_rt_reflection_strength, action_project_render_rt_reflection_strength, null, true, false, "", rtbadge, "fire_small")
				tab_next()
				
				tab_control_meter()
				draw_meter("renderrtroughnesscutoff", dx, dy, dw, round(project_render_rt_roughness_cutoff * 100), 0, 100, 90, 1, tab.render.tbx_rt_roughness_cutoff, action_project_render_rt_roughness_cutoff, "renderrtroughnesscutofftip", rtbadge, "fire_small")
				tab_next()
				
				tab_control_dragger()
				draw_dragger("renderrtreflectionbounces", dx, dy, dragger_width, project_render_rt_reflection_bounces, .1, 0, 16, 1, 1, tab.render.tbx_rt_reflection_bounces, action_project_render_rt_reflection_bounces, null, true, false, "renderrtreflectionbouncestip", rtbadge, "fire_small")
				tab_next()
				
			}
			else
			{
				tab_control_meter()
				draw_meter("renderrtreflectionsfade", dx, dy, dw, round(project_render_rt_reflections_fade * 100), 0, 100, 50, 1, tab.render.tbx_rt_reflections_fade, action_project_render_rt_reflections_fade, "renderrtreflectionsfadetip", rtbadge, "fire_small")
				tab_next()
				
			}
			
			tab_collapse_end(false)
		}
		
		// Specular highlights
		if (hw)
		{
			tab_control_switch()
			draw_switch("renderrtspecular", dx, dy, project_render_rt_specular, action_project_render_rt_specular, "renderrtspeculartip", false, rtbadge, "fire_small")
			tab_next()
			
		}
		
		tab_collapse_end()
	}
	
	// PBR materials (material and normal maps from resource packs)
	tab_control_switch()
	draw_button_collapse("pbr", collapse_map[?"pbr"], null, true, "renderpbr", "renderpbrtip")
	tab_next()
	
	if (collapse_map[?"pbr"])
	{
		tab_collapse_start()
		
		// Object material maps
		tab_control_switch()
		draw_switch("rendermaterialmaps", dx, dy, project_render_material_maps, action_project_render_material_maps, "rendermaterialmapstip")
		tab_next()
		
		// Pack maps for blocks
		tab_control_switch()
		draw_switch("renderpbrpackmaps", dx, dy, project_render_pbr_pack_maps, action_project_render_pbr_pack_maps, "renderpbrpackmapstip")
		tab_next()
		
		// Normal maps
		tab_control_switch()
		draw_button_collapse("pbr_normal", collapse_map[?"pbr_normal"], action_project_render_pbr_normal_maps, project_render_pbr_normal_maps, "renderpbrnormalmaps", "renderpbrnormalmapstip")
		tab_next()
		
		if (project_render_pbr_normal_maps && collapse_map[?"pbr_normal"])
		{
			tab_collapse_start()
			
			tab_control_dragger()
			draw_dragger("renderpbrnormalstrength", dx, dy, dragger_width, round(project_render_pbr_normal_strength * 100), .5, 0, 1000, 100, 1, tab.render.tbx_pbr_normal_strength, action_project_render_pbr_normal_strength, null, true, false, "renderpbrnormalstrengthtip")
			tab_next()
			
			tab_collapse_end(false)
		}
		
		// Material multipliers
		tab_control_dragger()
		draw_dragger("renderpbrroughness", dx, dy, dragger_width, round(project_render_pbr_roughness * 100), .5, 0, 1000, 100, 1, tab.render.tbx_pbr_roughness, action_project_render_pbr_roughness, null, true, false, "renderpbrroughnesstip")
		tab_next()
		
		tab_control_dragger()
		draw_dragger("renderpbrmetallic", dx, dy, dragger_width, round(project_render_pbr_metallic * 100), .5, 0, 1000, 100, 1, tab.render.tbx_pbr_metallic, action_project_render_pbr_metallic, null, true, false, "renderpbrmetallictip")
		tab_next()
		
		tab_control_dragger()
		draw_dragger("renderpbrreflectivity", dx, dy, dragger_width, round(project_render_pbr_reflectivity * 100), .5, 0, 1000, 100, 1, tab.render.tbx_pbr_reflectivity, action_project_render_pbr_reflectivity, null, true, false, "renderpbrreflectivitytip")
		tab_next()
		
		// Default emissive
		tab_control_dragger()
		draw_dragger("renderdefaultemissive", dx, dy, dragger_width, round(project_render_block_emissive * 100), 1, 0, no_limit, 100, 1, tab.render.tbx_block_emissive, action_project_render_block_emissive, null, true, false, "renderdefaultemissivetip")
		tab_next()
		
		// Default subsurface
		tab_control_dragger()
		draw_dragger("renderdefaultsubsurfaceradius", dx, dy, dragger_width, project_render_block_subsurface, .1, 0, no_limit, 8, 0.01, tab.render.tbx_block_subsurface_radius, action_project_render_block_subsurface, null, true, false, "renderdefaultsubsurfaceradiustip")
		tab_next()
		
		// Texture ambient occlusion (ray tracing)
		var rtbadge = text_get("renderraytracingbadge");
		tab_control_switch()
		draw_button_collapse("pbr_ao", collapse_map[?"pbr_ao"], action_project_render_pbr_texture_ao, project_render_pbr_texture_ao, "renderpbrtextureao", "renderpbrtextureaotip", rtbadge, "fire")
		tab_next()
		
		if (project_render_pbr_texture_ao && collapse_map[?"pbr_ao"])
		{
			tab_collapse_start()
			
			tab_control_meter()
			draw_meter("renderpbraostrength", dx, dy, dw, round(project_render_pbr_ao_strength * 100), 0, 200, 100, 1, tab.render.tbx_pbr_ao_strength, action_project_render_pbr_ao_strength, "", rtbadge, "fire_small")
			tab_next()
			
			tab_collapse_end(false)
		}
		
		tab_collapse_end()
	}
	
// Alpha mode
	text = (project_render_alpha_mode = e_alpha_mode.BLEND ? text_get("renderalphamodeblend") : text_get("renderalphamodehashed"));
	tab_control_menu()
	draw_button_menu("renderalphamode", e_menu.LIST, dx, dy, dw, 24, project_render_alpha_mode, text, action_project_render_alpha_mode)
	tab_next()
	
tab_control(24)
	
	// Import render settings
	if (draw_button_icon("renderimport", dx, dy, 24, 24, false, icons.SETTINGS_IMPORT, null, false, "tooltipsettingsimport"))
		action_project_render_import()
	
	// Export render settings
	if (draw_button_icon("renderexport", dx + 28, dy, 24, 24, false, icons.SETTINGS_EXPORT, null, false, "tooltipsettingsexport"))
		action_project_render_export()
	
	// Set current render settings as default
	if (draw_button_icon("rendersetdefault", dx + (28 * 2), dy, 24, 24, false, icons.SETTINGS_SETDEFAULT, null, false, "tooltipsettingssetdefault"))
	{
		if (question(text_get("questionsetasdefault")))
			action_project_render_export(render_default_file)
	}
	
	// Reset render settings
	draw_button_icon("renderreset", dx + (28 * 3), dy, 24, 24, false, icons.RESET, action_project_render_reset, false, "tooltipsettingsreset")
	
	tab_next()
}
