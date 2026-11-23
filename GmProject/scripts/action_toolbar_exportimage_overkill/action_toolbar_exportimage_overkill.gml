/// action_toolbar_exportimage_overkill()

function action_toolbar_exportimage_overkill()
{
	popup_exportimage.overkill = !popup_exportimage.overkill

	// OVERKILL is raytraced rendering taken all the way
	if (popup_exportimage.overkill)
		popup_exportimage.raytraced = true
}
