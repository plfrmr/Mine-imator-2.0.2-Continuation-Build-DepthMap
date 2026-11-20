/// action_tl_frame_reflectiveness(value, add)
/// @arg value
/// @arg add

function action_tl_frame_reflectiveness(val, add)
{
	tl_value_set_start(action_tl_frame_reflectiveness, true)
	tl_value_set(e_value.REFLECTIVENESS, val / 100, add)
	tl_value_set_done()
}
