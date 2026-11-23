/// action_toolbar_exportmodel_size(value, add)
/// @arg value
/// @arg add

function action_toolbar_exportmodel_size(val, add)
{
	popup_exportmodel.size_blocks = clamp(popup_exportmodel.size_blocks * add + val, 0.1, 3)
}
