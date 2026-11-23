/// action_toolbar_exportmodel_save()

function action_toolbar_exportmodel_save()
{
	var fn = file_dialog_save(text_get("filedialogsavemodel") + " (*.json)|*.json", filename_get_valid(project_name), "", text_get("filedialogsavemodelcaption"));
	if (fn = "")
		return 0

	popup_close()
	export_model(fn)
}
