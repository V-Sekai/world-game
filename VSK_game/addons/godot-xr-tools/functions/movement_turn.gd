@tool
class_name XRToolsMovementTurn
extends XRToolsMovementProvider


## XR Tools Movement Provider for Turning
##
## This script provides turning support for the player. This script works
## with the PlayerBody attached to the players XROrigin3D.


## Movement mode
enum TurnMode {
	DEFAULT,	## 
	SNAP,
	SMOOTH
}


## Movement provider order
@export var order : int = 5

## Movement mode property
@export var turn_mode : TurnMode = TurnMode.DEFAULT

## Smooth turn speed in radians per second
@export var smooth_turn_speed : float = 2.0

## Seconds per step (at maximum turn rate)
@export var step_turn_delay : float = 0.2

## Step turn angle in degrees
@export var step_turn_angle : float = 20.0

## Our directional input
@export var input_action : String = "primary"

# Turn step accumulator
var _turn_step : float = 0.0


# Controller node
@onready var _controller : XRController3D = get_parent()


func _ready():
	# In Godot 4 we must now manually call our super class ready function
	super._ready()


# Perform jump movement
func physics_movement(delta: float, player_body: XRToolsPlayerBody, _disabled: bool):
	# Skip if the controller isn't active
	if !_controller.get_is_active():
		return

	var deadzone = 0.1
	if _snap_turning():
		deadzone = XRTools.get_snap_turning_deadzone()

	# Read the left/right joystick axis
	var left_right := _controller.get_axis(input_action).x
	if abs(left_right) <= deadzone:
		# Not turning
		_turn_step = 0.0
		return

	# Handle smooth rotation
	if !_snap_turning():
		_rotate_player(player_body, smooth_turn_speed * delta * left_right)
		return

	# Update the next turn-step delay
	_turn_step -= abs(left_right) * delta
	if _turn_step >= 0.0:
		return

	# Turn one step in the requested direction
	_turn_step = step_turn_delay
	_rotate_player(player_body, deg_to_rad(step_turn_angle) * sign(left_right))


# Rotate the origin node around the camera
func _rotate_player(player_body: XRToolsPlayerBody, angle: float):
	var t1 := Transform3D()
	var t2 := Transform3D()
	var rot := Transform3D()

	t1.origin = -player_body.camera_node.transform.origin
	t2.origin = player_body.camera_node.transform.origin
	rot = rot.rotated(Vector3(0.0, -1.0, 0.0), angle)
	player_body.origin_node.transform = (player_body.origin_node.transform * t2 * rot * t1).orthonormalized()


# Test if snap turning should be used
func _snap_turning():
	if turn_mode == TurnMode.SNAP:
		return true
	elif turn_mode == TurnMode.SMOOTH:
		return false
	else:
		return XRToolsUserSettings.snap_turning


# This method verifies the movement provider has a valid configuration.
func _get_configuration_warning():
	# Check the controller node
	var test_controller = get_parent()
	if !test_controller or !test_controller is XRController3D:
		return "Unable to find ARVR Controller node"

	# Call base class
	return super._get_configuration_warning()
