/// gpu_adapter_display_name(name)
/// @arg name
/// @desc Returns the text shown for a graphics card preference in the Graphics card menu.

function gpu_adapter_display_name(name)
{
	if (name = "")
	{
		var current = gpu_adapter_get_current();
		return text_get("rendergpudefault") + (current != "" && render_gpu_startup = "" ? " (" + current + ")" : "")
	}
	
	if (name = "highperformance")
		return text_get("rendergpuhighperformance")
	
	return name
}
