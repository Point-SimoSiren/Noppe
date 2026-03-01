extends CharacterBody3D

const SPEED := 6.0
const SPRINT_MULTIPLIER := 1.75
const ACCELERATION := 18.0
const JUMP_VELOCITY := 5.5
const MOUSE_SENSITIVITY := 0.003
const MODEL_BASE_HEIGHT := 0.72

var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var animation_time := 0.0

@onready var look_pivot: Node3D = $LookPivot
@onready var model_root: Node3D = $ModelRoot
@onready var tail_root: Node3D = $ModelRoot/TailRoot

func _ready() -> void:
	_ensure_input_map()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion_event := event as InputEventMouseMotion
		rotate_y(-motion_event.relative.x * MOUSE_SENSITIVITY)
		look_pivot.rotate_x(-motion_event.relative.y * MOUSE_SENSITIVITY)
		look_pivot.rotation.x = clamp(look_pivot.rotation.x, deg_to_rad(-40.0), deg_to_rad(30.0))
		return

	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_basis: Basis = global_transform.basis
	var direction: Vector3 = (move_basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	var speed_scale: float = SPRINT_MULTIPLIER if Input.is_action_pressed("sprint") else 1.0

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY

	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var target_velocity: Vector3 = direction * SPEED * speed_scale
	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, ACCELERATION * delta)

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	move_and_slide()
	_update_animation(delta, input_vector, horizontal_velocity.length())


func _update_animation(delta: float, input_vector: Vector2, horizontal_speed: float) -> void:
	var speed_ratio: float = clamp(horizontal_speed / (SPEED * SPRINT_MULTIPLIER), 0.0, 1.0)
	var target_tail_y: float = 0.0

	if speed_ratio > 0.01:
		animation_time += delta * (3.5 + speed_ratio * 7.0)
		target_tail_y = sin(animation_time * 3.0) * 0.55 * speed_ratio

	model_root.rotation.z = lerp(model_root.rotation.z, -input_vector.x * 0.14, delta * 8.0)
	model_root.position.y = MODEL_BASE_HEIGHT + sin(animation_time * 2.0) * 0.04 * speed_ratio
	tail_root.rotation.y = lerp(tail_root.rotation.y, target_tail_y, delta * 8.0)


func _ensure_input_map() -> void:
	_ensure_action("move_forward", [KEY_W, KEY_UP])
	_ensure_action("move_back", [KEY_S, KEY_DOWN])
	_ensure_action("move_left", [KEY_A, KEY_LEFT])
	_ensure_action("move_right", [KEY_D, KEY_RIGHT])
	_ensure_action("jump", [KEY_SPACE])
	_ensure_action("sprint", [KEY_SHIFT])


func _ensure_action(action_name: StringName, keys: Array[int]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	if InputMap.action_get_events(action_name).size() > 0:
		return

	for key in keys:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = key
		InputMap.action_add_event(action_name, key_event)
