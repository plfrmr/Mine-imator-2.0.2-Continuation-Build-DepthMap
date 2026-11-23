/// action_toolbar_exportimage_raytraced()

function action_toolbar_exportimage_raytraced()
{
	popup_exportimage.raytraced = !popup_exportimage.raytraced
	if (!popup_exportimage.raytraced)
		popup_exportimage.overkill = false
}
