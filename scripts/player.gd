extends CharacterBody3D

const SPEED := 6.0
const SPRINT_MULTIPLIER := 1.75
const ACCELERATION := 18.0
const JUMP_VELOCITY := 5.5
const MOUSE_SENSITIVITY := 0.003
const MODEL_BASE_HEIGHT := 0.72
const MAX_HEALTH := 100.0
const ATTACK_DURATION := 0.32
const ATTACK_ROTATION := TAU * 1.08
const ATTACK_PIVOT_OFFSET_Z := 0.35
const ATTACK_RECOVERY_SPEED := 14.0
const SAFE_POND_DEFINITIONS := [
	{"center": Vector3(-32.0, 0.0, -24.0), "radius": 9.0},
	{"center": Vector3(26.0, 0.0, -6.0), "radius": 7.5},
	{"center": Vector3(8.0, 0.0, 34.0), "radius": 8.5},
]

var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var animation_time := 0.0
var max_health: float = MAX_HEALTH
var current_health: float = MAX_HEALTH
var spawn_position: Vector3 = Vector3.ZERO
var kills: int = 0
var footstep_timer: float = 0.0
var was_in_pond: bool = false
var is_attacking: bool = false
var attack_timer: float = 0.0
var attack_yaw: float = 0.0
var attack_hit_ids: Dictionary = {}

@onready var look_pivot: Node3D = $LookPivot
@onready var model_root: Node3D = $ModelRoot
@onready var tail_root: Node3D = $ModelRoot/TailRoot
@onready var tail_strike: Area3D = $ModelRoot/TailRoot/TailStrike
@onready var hurt_sound: AudioStreamPlayer = $HurtSound
@onready var heal_sound: AudioStreamPlayer = $HealSound
@onready var kill_sound: AudioStreamPlayer = $KillSound
@onready var footstep_sound: AudioStreamPlayer = $FootstepSound
@onready var splash_sound: AudioStreamPlayer = $SplashSound

signal health_changed(current: float, maximum: float)
signal kills_changed(total: int)

func _ready() -> void:
	_ensure_input_map()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	spawn_position = global_position
	add_to_group("player")
	_assign_sound_streams()
	tail_strike.body_entered.connect(_on_tail_strike_body_entered)
	was_in_pond = _is_in_safe_pond(global_position, -0.5)
	health_changed.emit(current_health, max_health)
	kills_changed.emit(kills)


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
	var speed_scale: float = SPRINT_MULTIPLIER if Input.is_action_pressed("sprint") and not is_attacking else 1.0

	if Input.is_action_just_pressed("tail_attack") and is_on_floor() and not is_attacking:
		_start_tail_attack()

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump") and not is_attacking:
		velocity.y = JUMP_VELOCITY

	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var target_velocity: Vector3 = direction * SPEED * speed_scale

	if is_attacking:
		target_velocity *= 0.18

	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, ACCELERATION * delta)

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	move_and_slide()
	_update_attack(delta)
	_update_footsteps(delta, horizontal_velocity.length(), speed_scale)
	_update_pond_state()
	_update_animation(delta, input_vector, horizontal_velocity.length())


func _update_animation(delta: float, input_vector: Vector2, horizontal_speed: float) -> void:
	var speed_ratio: float = clamp(horizontal_speed / (SPEED * SPRINT_MULTIPLIER), 0.0, 1.0)
	var target_tail_y: float = 0.0
	var target_bank_z: float = -input_vector.x * 0.14
	var bob_height: float = 0.0

	if speed_ratio > 0.01:
		animation_time += delta * (3.5 + speed_ratio * 7.0)
		target_tail_y = sin(animation_time * 3.0) * 0.55 * speed_ratio
		bob_height = sin(animation_time * 2.0) * 0.04 * speed_ratio

	if is_attacking:
		var attack_ratio: float = clamp(attack_timer / ATTACK_DURATION, 0.0, 1.0)
		target_tail_y = lerp(1.2, -0.4, attack_ratio)
		target_bank_z = sin(attack_ratio * PI) * 0.08
		bob_height = sin(attack_ratio * PI) * 0.03

	_apply_model_pose(delta, target_bank_z, bob_height)
	tail_root.rotation.y = lerp(tail_root.rotation.y, target_tail_y, delta * 8.0)


func _ensure_input_map() -> void:
	_set_action_keys("move_forward", [KEY_W, KEY_UP])
	_set_action_keys("move_back", [KEY_S, KEY_DOWN])
	_set_action_keys("move_left", [KEY_A, KEY_LEFT])
	_set_action_keys("move_right", [KEY_D, KEY_RIGHT])
	_set_action_keys("jump", [KEY_CTRL])
	_set_action_keys("tail_attack", [KEY_SPACE])
	_set_action_keys("sprint", [KEY_SHIFT])


func _set_action_keys(action_name: StringName, keys: Array[int]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	InputMap.action_erase_events(action_name)

	for key in keys:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = key
		InputMap.action_add_event(action_name, key_event)


func take_damage(amount: float) -> void:
	if amount <= 0.0 or is_attacking:
		return

	current_health = max(current_health - amount, 0.0)
	_play_sound(hurt_sound)
	health_changed.emit(current_health, max_health)

	if current_health <= 0.0:
		_respawn()


func heal(amount: float) -> void:
	if amount <= 0.0:
		return

	current_health = min(current_health + amount, max_health)
	_play_sound(heal_sound)
	health_changed.emit(current_health, max_health)


func _respawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	current_health = max_health
	health_changed.emit(current_health, max_health)


func _on_tail_strike_body_entered(body: Node3D) -> void:
	if not is_attacking or not body.is_in_group("ant_enemy"):
		return

	var body_id := body.get_instance_id()
	if attack_hit_ids.has(body_id):
		return

	attack_hit_ids[body_id] = true

	var attack_origin: Vector3 = to_global(Vector3(0.0, MODEL_BASE_HEIGHT, ATTACK_PIVOT_OFFSET_Z))
	var launch_direction := body.global_position - attack_origin
	launch_direction.y = 0.0

	if launch_direction.length_squared() <= 0.001:
		launch_direction = -global_transform.basis.z

	var defeated := false
	if body.has_method("launch_and_die"):
		defeated = bool(body.call("launch_and_die", launch_direction.normalized(), 7.2))
	elif body.has_method("squash"):
		defeated = bool(body.call("squash"))

	if defeated:
		kills += 1
		_play_sound(kill_sound)
		kills_changed.emit(kills)


func _play_sound(player: AudioStreamPlayer) -> void:
	if player == null:
		return

	player.stop()
	player.play()


func _assign_sound_streams() -> void:
	hurt_sound.stream = _build_tone_stream(220.0, 0.18, 0.42)
	heal_sound.stream = _build_tone_stream(660.0, 0.22, 0.28)
	kill_sound.stream = _build_tone_stream(880.0, 0.14, 0.24)
	footstep_sound.stream = _build_noise_step_stream()
	splash_sound.stream = _build_splash_stream()


func _build_tone_stream(frequency: float, duration: float, volume: float) -> AudioStreamWAV:
	var sample_rate := 44100
	var sample_count := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	for i in sample_count:
		var time := float(i) / float(sample_rate)
		var envelope := 1.0 - (float(i) / float(max(sample_count, 1)))
		var sample_value := sin(TAU * frequency * time) * volume * envelope
		var pcm := int(clamp(sample_value * 32767.0, -32768.0, 32767.0))
		var encoded := pcm & 0xFFFF
		data[i * 2] = encoded & 0xFF
		data[i * 2 + 1] = (encoded >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream


func _build_noise_step_stream() -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(0.08 * sample_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	for i in sample_count:
		var progress := float(i) / float(sample_count)
		var envelope := 1.0 - progress
		var grain := randf_range(-1.0, 1.0) * 0.22 * envelope
		var thump := sin(TAU * 90.0 * (float(i) / float(sample_rate))) * 0.08 * envelope
		var pcm := int(clamp((grain + thump) * 32767.0, -32768.0, 32767.0))
		var encoded := pcm & 0xFFFF
		data[i * 2] = encoded & 0xFF
		data[i * 2 + 1] = (encoded >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream


func _build_splash_stream() -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(0.24 * sample_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	for i in sample_count:
		var progress := float(i) / float(sample_count)
		var envelope := 1.0 - progress
		var fizz := randf_range(-1.0, 1.0) * 0.18 * envelope
		var wobble := sin(TAU * (260.0 - progress * 180.0) * (float(i) / float(sample_rate))) * 0.1 * envelope
		var pcm := int(clamp((fizz + wobble) * 32767.0, -32768.0, 32767.0))
		var encoded := pcm & 0xFFFF
		data[i * 2] = encoded & 0xFF
		data[i * 2 + 1] = (encoded >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream


func _update_footsteps(delta: float, horizontal_speed: float, speed_scale: float) -> void:
	if is_attacking or not is_on_floor() or horizontal_speed < 0.35:
		footstep_timer = 0.0
		return

	footstep_timer -= delta

	if footstep_timer > 0.0:
		return

	_play_sound(footstep_sound)
	footstep_timer = 0.32 / max(speed_scale, 1.0)


func _update_pond_state() -> void:
	var in_pond_now: bool = _is_in_safe_pond(global_position, -0.5)

	if in_pond_now != was_in_pond:
		_play_sound(splash_sound)
		was_in_pond = in_pond_now


func _is_in_safe_pond(position: Vector3, padding: float) -> bool:
	for pond_data in SAFE_POND_DEFINITIONS:
		var center: Vector3 = pond_data["center"]
		var radius: float = pond_data["radius"]
		var flat_position := Vector3(position.x, 0.0, position.z)

		if flat_position.distance_to(center) <= radius + padding:
			return true

	return false


func _start_tail_attack() -> void:
	is_attacking = true
	attack_timer = 0.0
	attack_hit_ids.clear()
	footstep_timer = 0.0


func _update_attack(delta: float) -> void:
	if not is_attacking:
		attack_yaw = lerp_angle(attack_yaw, 0.0, delta * ATTACK_RECOVERY_SPEED)
		return

	attack_timer += delta
	var attack_ratio: float = clamp(attack_timer / ATTACK_DURATION, 0.0, 1.0)
	var eased_ratio: float = 1.0 - pow(1.0 - attack_ratio, 3.0)
	attack_yaw = eased_ratio * ATTACK_ROTATION

	if attack_timer >= ATTACK_DURATION:
		is_attacking = false
		attack_timer = 0.0
		attack_hit_ids.clear()


func _apply_model_pose(delta: float, target_bank_z: float, bob_height: float) -> void:
	var pivot_position := Vector3(0.0, MODEL_BASE_HEIGHT, ATTACK_PIVOT_OFFSET_Z)
	var rest_offset := Vector3(0.0, 0.0, -ATTACK_PIVOT_OFFSET_Z)
	var rotated_offset := rest_offset.rotated(Vector3.UP, attack_yaw)

	model_root.position = pivot_position + rotated_offset
	model_root.position.y += bob_height
	model_root.rotation.y = attack_yaw
	model_root.rotation.z = lerp(model_root.rotation.z, target_bank_z, delta * 8.0)
