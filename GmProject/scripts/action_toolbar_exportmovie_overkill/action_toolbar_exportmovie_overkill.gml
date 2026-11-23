/// action_toolbar_exportmovie_overkill()

function action_toolbar_exportmovie_overkill()
{
	popup.overkill = !popup.overkill

	// OVERKILL is raytraced rendering taken all the way
	if (popup.overkill)
		popup.raytraced = true
}
