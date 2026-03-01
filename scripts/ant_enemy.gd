extends CharacterBody3D

const WALK_SPEED := 3.6
const CHASE_SPEED := 6.4
const ACCELERATION := 16.0
const TURN_SPEED := 7.0
const DETECT_RADIUS := 20.0
const BITE_RADIUS := 1.4
const BITE_DAMAGE := 10.0
const BITE_COOLDOWN := 0.55
const WANDER_RADIUS := 28.0
const MODEL_BASE_HEIGHT := 0.18
const SAFE_POND_DEFINITIONS := [
	{"center": Vector3(-32.0, 0.0, -24.0), "radius": 9.0},
	{"center": Vector3(26.0, 0.0, -6.0), "radius": 7.5},
	{"center": Vector3(8.0, 0.0, 34.0), "radius": 8.5},
]

var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var bite_cooldown: float = 0.0
var wander_timer: float = 0.0
var animation_time: float = 0.0
var home_position: Vector3 = Vector3.ZERO
var move_direction: Vector3 = Vector3.FORWARD
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var player_ref: Node3D
var is_dying: bool = false
var chatter_timer: float = 0.0
var death_timer: float = 0.0

@onready var model_root: Node3D = $ModelRoot
@onready var leg_root_left: Node3D = $ModelRoot/LegRootLeft
@onready var leg_root_right: Node3D = $ModelRoot/LegRootRight
@onready var antenna_left: MeshInstance3D = $ModelRoot/AntennaLeft
@onready var antenna_right: MeshInstance3D = $ModelRoot/AntennaRight
@onready var chatter_sound: AudioStreamPlayer3D = $ChatterSound
@onready var bite_sound: AudioStreamPlayer3D = $BiteSound
@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	home_position = global_position
	rng.randomize()
	add_to_group("ant_enemy")
	_assign_sound_streams()
	_pick_new_direction()
	_refresh_player_reference()
	_reset_chatter_timer()


func _physics_process(delta: float) -> void:
	if is_dying:
		_update_death_motion(delta)
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if bite_cooldown > 0.0:
		bite_cooldown -= delta

	chatter_timer -= delta
	wander_timer -= delta
	_refresh_player_reference()

	var desired_direction: Vector3 = move_direction
	var target_speed: float = WALK_SPEED
	var inside_pond: bool = _is_in_safe_pond(global_position, 0.4)

	if inside_pond:
		desired_direction = _get_pond_escape_direction(global_position)
		target_speed = CHASE_SPEED

	if player_ref != null:
		var to_player: Vector3 = player_ref.global_position - global_position
		to_player.y = 0.0
		var distance_to_player: float = to_player.length()
		var player_safe: bool = _is_in_safe_pond(player_ref.global_position, -0.7)

		if not inside_pond and not player_safe and distance_to_player <= DETECT_RADIUS and distance_to_player > 0.001:
			desired_direction = to_player.normalized()
			target_speed = CHASE_SPEED

			if distance_to_player <= BITE_RADIUS and bite_cooldown <= 0.0:
				if player_ref.has_method("take_damage"):
					player_ref.call("take_damage", BITE_DAMAGE)
				_play_sound_3d(bite_sound)
				bite_cooldown = BITE_COOLDOWN
		elif inside_pond:
			desired_direction = _get_pond_escape_direction(global_position)
			target_speed = CHASE_SPEED
		elif global_position.distance_to(home_position) > WANDER_RADIUS:
			desired_direction = (home_position - global_position).normalized()
			desired_direction.y = 0.0
		elif wander_timer <= 0.0:
			_pick_new_direction()
			desired_direction = move_direction
	else:
		if inside_pond:
			desired_direction = _get_pond_escape_direction(global_position)
			target_speed = CHASE_SPEED
		elif global_position.distance_to(home_position) > WANDER_RADIUS:
			desired_direction = (home_position - global_position).normalized()
			desired_direction.y = 0.0
		elif wander_timer <= 0.0:
			_pick_new_direction()
			desired_direction = move_direction

	if desired_direction.length_squared() > 0.001:
		move_direction = desired_direction.normalized()
		rotation.y = lerp_angle(rotation.y, atan2(-move_direction.x, -move_direction.z), delta * TURN_SPEED)

	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var target_velocity: Vector3 = move_direction * target_speed
	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, ACCELERATION * delta)

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	move_and_slide()
	_update_animation(delta, horizontal_velocity.length())
	_update_chatter(horizontal_velocity.length(), target_speed)


func _pick_new_direction() -> void:
	wander_timer = rng.randf_range(1.2, 2.7)
	var angle: float = rng.randf_range(0.0, TAU)
	move_direction = Vector3(sin(angle), 0.0, cos(angle)).normalized()


func _refresh_player_reference() -> void:
	if player_ref != null and is_instance_valid(player_ref):
		return

	player_ref = get_tree().get_first_node_in_group("player") as Node3D


func _update_animation(delta: float, horizontal_speed: float) -> void:
	var speed_ratio: float = clamp(horizontal_speed / CHASE_SPEED, 0.0, 1.0)
	animation_time += delta * (4.0 + speed_ratio * 8.0)

	model_root.position.y = MODEL_BASE_HEIGHT + sin(animation_time * 2.0) * 0.015 * speed_ratio
	leg_root_left.rotation.z = sin(animation_time * 5.0) * 0.22 * speed_ratio
	leg_root_right.rotation.z = -sin(animation_time * 5.0) * 0.22 * speed_ratio
	antenna_left.rotation.x = deg_to_rad(-30.0) + sin(animation_time * 3.0) * 0.08
	antenna_right.rotation.x = deg_to_rad(-30.0) - sin(animation_time * 3.0) * 0.08


func squash() -> bool:
	return launch_and_die(-global_transform.basis.z, 5.8)


func launch_and_die(direction: Vector3, force: float = 7.0) -> bool:
	if is_dying:
		return false

	is_dying = true
	death_timer = 0.42
	remove_from_group("ant_enemy")
	collision_layer = 0
	collision_mask = 0
	collision_shape.disabled = true

	var launch_direction := direction.normalized()
	if launch_direction.length_squared() <= 0.001:
		launch_direction = -global_transform.basis.z

	velocity = launch_direction * force + Vector3(0.0, 2.6, 0.0)
	return true


func _assign_sound_streams() -> void:
	chatter_sound.stream = _build_chatter_stream()
	bite_sound.stream = _build_bite_stream()


func _build_chatter_stream() -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(0.1 * sample_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	for i in sample_count:
		var progress := float(i) / float(sample_count)
		var envelope := 1.0 - progress
		var scratch := randf_range(-1.0, 1.0) * 0.15 * envelope
		var chirp := sin(TAU * (1100.0 + progress * 600.0) * (float(i) / float(sample_rate))) * 0.08 * envelope
		var pcm := int(clamp((scratch + chirp) * 32767.0, -32768.0, 32767.0))
		var encoded := pcm & 0xFFFF
		data[i * 2] = encoded & 0xFF
		data[i * 2 + 1] = (encoded >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream


func _build_bite_stream() -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(0.08 * sample_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	for i in sample_count:
		var progress := float(i) / float(sample_count)
		var envelope := 1.0 - progress
		var click := randf_range(-1.0, 1.0) * 0.22 * envelope
		var tone := sin(TAU * 540.0 * (float(i) / float(sample_rate))) * 0.06 * envelope
		var pcm := int(clamp((click + tone) * 32767.0, -32768.0, 32767.0))
		var encoded := pcm & 0xFFFF
		data[i * 2] = encoded & 0xFF
		data[i * 2 + 1] = (encoded >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream


func _update_chatter(horizontal_speed: float, target_speed: float) -> void:
	if chatter_timer > 0.0 or horizontal_speed < 0.4:
		return

	_play_sound_3d(chatter_sound)
	var movement_ratio: float = clamp(horizontal_speed / max(target_speed, 0.1), 0.0, 1.0)
	chatter_timer = lerp(1.3, 0.35, movement_ratio)


func _reset_chatter_timer() -> void:
	chatter_timer = rng.randf_range(0.25, 1.0)


func _play_sound_3d(player: AudioStreamPlayer3D) -> void:
	if player == null:
		return

	player.stop()
	player.play()


func _is_in_safe_pond(position: Vector3, padding: float) -> bool:
	for pond_data in SAFE_POND_DEFINITIONS:
		var center: Vector3 = pond_data["center"]
		var radius: float = pond_data["radius"]
		var flat_position := Vector3(position.x, 0.0, position.z)

		if flat_position.distance_to(center) <= radius + padding:
			return true

	return false


func _get_pond_escape_direction(position: Vector3) -> Vector3:
	for pond_data in SAFE_POND_DEFINITIONS:
		var center: Vector3 = pond_data["center"]
		var radius: float = pond_data["radius"]
		var flat_position := Vector3(position.x, 0.0, position.z)

		if flat_position.distance_to(center) <= radius + 1.0:
			var away: Vector3 = (flat_position - center).normalized()
			if away.length_squared() > 0.001:
				return away

	return move_direction


func _update_death_motion(delta: float) -> void:
	death_timer -= delta
	velocity.y -= gravity * delta
	move_and_slide()
	model_root.rotation.x += delta * 12.0
	model_root.rotation.z += delta * 16.0

	if death_timer <= 0.0:
		queue_free()
