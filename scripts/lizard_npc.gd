extends CharacterBody3D

const WALK_SPEED := 2.4
const ACCELERATION := 8.0
const TURN_SPEED := 4.5
const MODEL_BASE_HEIGHT := 0.72
const WANDER_RADIUS := 18.0

@export var body_color: Color = Color(0.27, 0.55, 0.31, 1.0)
@export var detail_color: Color = Color(0.66, 0.83, 0.43, 1.0)
@export var wander_mood: float = 1.0

var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var animation_time: float = 0.0
var turn_timer: float = 0.0
var home_position: Vector3 = Vector3.ZERO
var move_direction: Vector3 = Vector3.FORWARD
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var model_root: Node3D = $ModelRoot
@onready var tail_root: Node3D = $ModelRoot/TailRoot
@onready var body_mesh: MeshInstance3D = $ModelRoot/Body
@onready var head_mesh: MeshInstance3D = $ModelRoot/Head
@onready var tail_mesh: MeshInstance3D = $ModelRoot/TailRoot/Tail
@onready var leg_meshes: Array[MeshInstance3D] = [
	$ModelRoot/FrontLeftLeg,
	$ModelRoot/FrontRightLeg,
	$ModelRoot/BackLeftLeg,
	$ModelRoot/BackRightLeg,
]

func _ready() -> void:
	home_position = global_position
	rng.randomize()
	_apply_colors()
	_pick_new_direction()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	turn_timer -= delta

	var desired_direction: Vector3 = move_direction
	var distance_from_home: float = global_position.distance_to(home_position)

	if distance_from_home > WANDER_RADIUS:
		desired_direction = (home_position - global_position).normalized()
		desired_direction.y = 0.0
	elif turn_timer <= 0.0:
		_pick_new_direction()
		desired_direction = move_direction

	if desired_direction.length_squared() > 0.001:
		desired_direction = desired_direction.normalized()
		move_direction = desired_direction
		rotation.y = lerp_angle(rotation.y, atan2(-desired_direction.x, -desired_direction.z), delta * TURN_SPEED)

	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var target_velocity: Vector3 = move_direction * WALK_SPEED * max(wander_mood, 0.45)
	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, ACCELERATION * delta)

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	move_and_slide()
	_update_animation(delta, horizontal_velocity.length())


func _pick_new_direction() -> void:
	turn_timer = rng.randf_range(1.4, 3.8) / max(wander_mood, 0.35)

	var angle: float = rng.randf_range(0.0, TAU)
	move_direction = Vector3(sin(angle), 0.0, cos(angle)).normalized()


func _update_animation(delta: float, horizontal_speed: float) -> void:
	var speed_ratio: float = clamp(horizontal_speed / (WALK_SPEED * max(wander_mood, 0.45)), 0.0, 1.0)
	var target_tail_y: float = 0.0

	if speed_ratio > 0.01:
		animation_time += delta * (2.2 + speed_ratio * 4.6)
		target_tail_y = sin(animation_time * 2.7) * 0.48 * speed_ratio

	model_root.rotation.z = lerp(model_root.rotation.z, sin(animation_time) * 0.04 * speed_ratio, delta * 6.0)
	model_root.position.y = MODEL_BASE_HEIGHT + sin(animation_time * 2.0) * 0.03 * speed_ratio
	tail_root.rotation.y = lerp(tail_root.rotation.y, target_tail_y, delta * 6.0)


func _apply_colors() -> void:
	var body_material: StandardMaterial3D = StandardMaterial3D.new()
	body_material.albedo_color = body_color
	body_material.roughness = 0.9

	var detail_material: StandardMaterial3D = StandardMaterial3D.new()
	detail_material.albedo_color = detail_color
	detail_material.roughness = 0.85

	body_mesh.material_override = body_material
	tail_mesh.material_override = body_material

	for leg_mesh in leg_meshes:
		leg_mesh.material_override = body_material

	head_mesh.material_override = detail_material
