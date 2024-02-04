extends Label3D

class_name PinLabel3D

@export var skeleton: Skeleton3D = null
@export var bone_name: String

func _ready():
	assert(skeleton != null, "Skeleton3D has not been assigned.")

func _process(delta):
	if skeleton == null:
		return

	var targets_3d: Marker3D = get_parent()

	var bone_i: int = skeleton.find_bone(bone_name)
	if bone_i == -1:
		return
	
	var current_pose: Transform3D = targets_3d.global_transform
	var pose: Transform3D = skeleton.get_bone_global_pose(bone_i)
	
	var diff_vec: Vector3 = pose.origin - current_pose.origin 
	text = vector_to_color_bars(diff_vec)


func value_to_color(value: float) -> String:
	return "%0.1f%%" % [value * 100]


func vector_to_color_bars(vec: Vector3) -> String:
	var right_bar := value_to_color(vec.x)
	var up_bar := value_to_color(vec.y)
	var forward_bar := value_to_color(vec.z)
	return "R|%s\nU|%s\nF|%s" % [right_bar, up_bar, forward_bar]
