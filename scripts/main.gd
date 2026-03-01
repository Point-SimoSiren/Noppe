extends Node3D

const TERRAIN_HALF_EXTENT := 100.0
const TREE_COUNT := 140
const ROCK_COUNT := 46
const STUMP_COUNT := 14
const LOG_COUNT := 12
const BRANCH_COUNT := 20
const ANTS_COUNT := 24
const NEST_COUNT := 6
const MAX_ANTS := 36
const FOOD_COUNT := 18
const FOOD_RESPAWN_DELAY := 5.0
const POND_DEFINITIONS := [
	{"center": Vector3(-32.0, 0.02, -24.0), "radius": 9.0},
	{"center": Vector3(26.0, 0.02, -6.0), "radius": 7.5},
	{"center": Vector3(8.0, 0.02, 34.0), "radius": 8.5},
]

const ANT_SCENE := preload("res://scenes/AntEnemy.tscn")
const FOOD_SCENE := preload("res://scenes/FoodPickup.tscn")

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var occupied_tree_positions: Array[Vector3] = []
var nest_positions: Array[Vector3] = []

var trunk_material: StandardMaterial3D = StandardMaterial3D.new()
var bark_light_material: StandardMaterial3D = StandardMaterial3D.new()
var canopy_dark_material: StandardMaterial3D = StandardMaterial3D.new()
var canopy_light_material: StandardMaterial3D = StandardMaterial3D.new()
var canopy_blue_material: StandardMaterial3D = StandardMaterial3D.new()
var rock_gray_material: StandardMaterial3D = StandardMaterial3D.new()
var rock_warm_material: StandardMaterial3D = StandardMaterial3D.new()
var water_material: StandardMaterial3D = StandardMaterial3D.new()
var reed_material: StandardMaterial3D = StandardMaterial3D.new()
var food_leaf_material: StandardMaterial3D = StandardMaterial3D.new()

var trunk_mesh: CylinderMesh = CylinderMesh.new()
var pine_layer_mesh: CylinderMesh = CylinderMesh.new()
var round_canopy_mesh: SphereMesh = SphereMesh.new()
var wide_canopy_mesh: SphereMesh = SphereMesh.new()
var shrub_mesh: SphereMesh = SphereMesh.new()
var round_rock_mesh: SphereMesh = SphereMesh.new()
var angular_rock_mesh: BoxMesh = BoxMesh.new()
var slab_rock_mesh: BoxMesh = BoxMesh.new()
var stump_mesh: CylinderMesh = CylinderMesh.new()
var fallen_log_mesh: CylinderMesh = CylinderMesh.new()
var branch_mesh: CylinderMesh = CylinderMesh.new()
var pond_mesh: CylinderMesh = CylinderMesh.new()
var reed_mesh: CylinderMesh = CylinderMesh.new()
var nest_mesh: CylinderMesh = CylinderMesh.new()

@onready var player = $Player
@onready var generated_world: Node3D = $GeneratedWorld
@onready var enemies_root: Node3D = $Ants
@onready var food_root: Node3D = $Food
@onready var health_label: Label = $CanvasLayer/HealthLabel
@onready var kills_label: Label = $CanvasLayer/KillsLabel
@onready var ambience_sound: AudioStreamPlayer = $AmbienceSound
@onready var greeting_sound: AudioStreamPlayer = $GreetingSound


func _ready() -> void:
	rng.randomize()
	_setup_resources()
	_setup_audio()
	_connect_player_health()
	_generate_landscape()
	_generate_nests()
	_spawn_ant_swarm(ANTS_COUNT)
	_spawn_food_batch(FOOD_COUNT)
	_start_nest_spawner()
	greeting_sound.play()


func _setup_resources() -> void:
	trunk_material.albedo_color = Color(0.36, 0.23, 0.14, 1.0)
	trunk_material.roughness = 0.96

	bark_light_material.albedo_color = Color(0.5, 0.38, 0.25, 1.0)
	bark_light_material.roughness = 0.98

	canopy_dark_material.albedo_color = Color(0.16, 0.39, 0.16, 1.0)
	canopy_dark_material.roughness = 0.94

	canopy_light_material.albedo_color = Color(0.24, 0.52, 0.22, 1.0)
	canopy_light_material.roughness = 0.95

	canopy_blue_material.albedo_color = Color(0.2, 0.44, 0.3, 1.0)
	canopy_blue_material.roughness = 0.95

	rock_gray_material.albedo_color = Color(0.43, 0.44, 0.4, 1.0)
	rock_gray_material.roughness = 1.0

	rock_warm_material.albedo_color = Color(0.46, 0.4, 0.34, 1.0)
	rock_warm_material.roughness = 1.0

	water_material.albedo_color = Color(0.15, 0.45, 0.58, 0.95)
	water_material.roughness = 0.12
	water_material.metallic = 0.05

	reed_material.albedo_color = Color(0.44, 0.56, 0.2, 1.0)
	reed_material.roughness = 0.92

	food_leaf_material.albedo_color = Color(0.22, 0.52, 0.22, 1.0)
	food_leaf_material.roughness = 0.9

	trunk_mesh.top_radius = 0.17
	trunk_mesh.bottom_radius = 0.32
	trunk_mesh.height = 4.4

	pine_layer_mesh.top_radius = 0.0
	pine_layer_mesh.bottom_radius = 1.0
	pine_layer_mesh.height = 2.4

	round_canopy_mesh.radius = 1.6
	round_canopy_mesh.height = 3.2

	wide_canopy_mesh.radius = 1.3
	wide_canopy_mesh.height = 2.6

	shrub_mesh.radius = 0.9
	shrub_mesh.height = 1.8

	round_rock_mesh.radius = 1.0
	round_rock_mesh.height = 2.0

	angular_rock_mesh.size = Vector3(2.2, 1.6, 1.8)
	slab_rock_mesh.size = Vector3(2.8, 1.0, 1.6)

	stump_mesh.top_radius = 0.42
	stump_mesh.bottom_radius = 0.5
	stump_mesh.height = 0.8

	fallen_log_mesh.top_radius = 0.2
	fallen_log_mesh.bottom_radius = 0.26
	fallen_log_mesh.height = 4.4

	branch_mesh.top_radius = 0.05
	branch_mesh.bottom_radius = 0.065
	branch_mesh.height = 1.3

	pond_mesh.top_radius = 1.0
	pond_mesh.bottom_radius = 1.0
	pond_mesh.height = 0.08

	reed_mesh.top_radius = 0.025
	reed_mesh.bottom_radius = 0.04
	reed_mesh.height = 0.7

	nest_mesh.top_radius = 1.0
	nest_mesh.bottom_radius = 1.45
	nest_mesh.height = 1.0


func _setup_audio() -> void:
	ambience_sound.stream = _build_forest_ambience_stream()
	greeting_sound.stream = _build_greeting_stream()
	ambience_sound.play()


func _connect_player_health() -> void:
	if player.has_signal("health_changed"):
		player.health_changed.connect(_on_player_health_changed)
	if player.has_signal("kills_changed"):
		player.kills_changed.connect(_on_player_kills_changed)

	_on_player_health_changed(player.current_health, player.max_health)
	_on_player_kills_changed(player.kills)


func _generate_landscape() -> void:
	_build_ponds()
	_generate_forest()
	_generate_rocks()
	_generate_deadwood()
	_generate_shrubs()


func _build_ponds() -> void:
	var ponds_root := Node3D.new()
	ponds_root.name = "Ponds"
	generated_world.add_child(ponds_root)

	for pond_data in POND_DEFINITIONS:
		var pond := Node3D.new()
		var center: Vector3 = pond_data["center"]
		var radius: float = pond_data["radius"]

		pond.position = center
		ponds_root.add_child(pond)

		_add_mesh(pond, pond_mesh, water_material, Vector3(0.0, 0.01, 0.0), Vector3.ZERO, Vector3(radius, 1.0, radius))

		for ring_index in range(8):
			var angle: float = (TAU / 8.0) * ring_index + rng.randf_range(-0.18, 0.18)
			var rock_distance: float = radius + rng.randf_range(0.4, 1.4)
			var rock_position := Vector3(cos(angle) * rock_distance, 0.22, sin(angle) * rock_distance)
			var rock_scale := Vector3(rng.randf_range(0.22, 0.45), rng.randf_range(0.12, 0.28), rng.randf_range(0.18, 0.4))
			var rock_rotation := Vector3(rng.randf_range(-12.0, 12.0), rng.randf_range(0.0, 180.0), rng.randf_range(-12.0, 12.0))
			_add_rock_body(pond, angular_rock_mesh, rock_gray_material, rock_position, rock_rotation, rock_scale, "box")

		for reed_index in range(10):
			var reed_angle: float = rng.randf_range(0.0, TAU)
			var reed_distance: float = rng.randf_range(radius - 0.8, radius + 0.9)
			var reed_position := Vector3(cos(reed_angle) * reed_distance, 0.34, sin(reed_angle) * reed_distance)
			var reed_rotation := Vector3(rng.randf_range(-8.0, 8.0), rng.randf_range(0.0, 180.0), rng.randf_range(-8.0, 8.0))
			var reed_scale := Vector3(rng.randf_range(0.7, 1.2), rng.randf_range(0.9, 1.5), rng.randf_range(0.7, 1.2))
			_add_mesh(pond, reed_mesh, reed_material, reed_position, reed_rotation, reed_scale)


func _generate_forest() -> void:
	var forest_root := Node3D.new()
	forest_root.name = "Forest"
	generated_world.add_child(forest_root)

	occupied_tree_positions.clear()

	for tree_index in range(TREE_COUNT):
		var tree_position: Vector3 = _find_tree_position()
		var tree_variant: int = tree_index % 3
		var tree_scale: float = rng.randf_range(0.82, 1.45)
		_spawn_tree(forest_root, tree_position, tree_variant, tree_scale)


func _generate_rocks() -> void:
	var rocks_root := Node3D.new()
	rocks_root.name = "Rocks"
	generated_world.add_child(rocks_root)

	for _rock_index in range(ROCK_COUNT):
		var rock_position: Vector3 = _random_walkable_position(7.0, 8.0)
		var rock_variant: int = rng.randi_range(0, 2)
		var rotation := Vector3(rng.randf_range(-20.0, 20.0), rng.randf_range(0.0, 180.0), rng.randf_range(-20.0, 20.0))

		match rock_variant:
			0:
				_add_rock_body(
					rocks_root,
					angular_rock_mesh,
					rock_gray_material,
					rock_position + Vector3(0.0, 0.55, 0.0),
					rotation,
					Vector3(rng.randf_range(0.45, 1.5), rng.randf_range(0.35, 1.0), rng.randf_range(0.45, 1.3)),
					"box"
				)
			1:
				_add_rock_body(
					rocks_root,
					slab_rock_mesh,
					rock_warm_material,
					rock_position + Vector3(0.0, 0.42, 0.0),
					rotation,
					Vector3(rng.randf_range(0.4, 1.3), rng.randf_range(0.28, 0.82), rng.randf_range(0.4, 1.2)),
					"box"
				)
			_:
				_add_rock_body(
					rocks_root,
					round_rock_mesh,
					rock_gray_material,
					rock_position + Vector3(0.0, 0.58, 0.0),
					rotation,
					Vector3(rng.randf_range(0.35, 1.2), rng.randf_range(0.3, 0.95), rng.randf_range(0.35, 1.1)),
					"sphere"
				)


func _generate_deadwood() -> void:
	var deadwood_root := Node3D.new()
	deadwood_root.name = "Deadwood"
	generated_world.add_child(deadwood_root)

	for _stump_index in range(STUMP_COUNT):
		var stump_position: Vector3 = _random_walkable_position(5.0, 10.0)
		_add_mesh(
			deadwood_root,
			stump_mesh,
			bark_light_material,
			stump_position + Vector3(0.0, 0.38, 0.0),
			Vector3.ZERO,
			Vector3.ONE * rng.randf_range(0.7, 1.25)
		)

	for _log_index in range(LOG_COUNT):
		var log_position: Vector3 = _random_walkable_position(6.0, 12.0)
		var log_rotation := Vector3(rng.randf_range(-12.0, 12.0), rng.randf_range(0.0, 180.0), rng.randf_range(78.0, 92.0))
		_add_mesh(
			deadwood_root,
			fallen_log_mesh,
			trunk_material,
			log_position + Vector3(0.0, 0.24, 0.0),
			log_rotation,
			Vector3.ONE * rng.randf_range(0.75, 1.3)
		)

	for _branch_index in range(BRANCH_COUNT):
		var branch_position: Vector3 = _random_walkable_position(4.0, 8.0)
		var branch_rotation := Vector3(rng.randf_range(-10.0, 10.0), rng.randf_range(0.0, 180.0), rng.randf_range(70.0, 90.0))
		_add_mesh(
			deadwood_root,
			branch_mesh,
			bark_light_material,
			branch_position + Vector3(0.0, 0.12, 0.0),
			branch_rotation,
			Vector3.ONE * rng.randf_range(0.7, 1.3)
		)


func _generate_shrubs() -> void:
	var shrubs_root := Node3D.new()
	shrubs_root.name = "Shrubs"
	generated_world.add_child(shrubs_root)

	for _shrub_index in range(36):
		var shrub_position: Vector3 = _random_walkable_position(5.0, 9.0)
		var shrub_material: StandardMaterial3D = canopy_light_material if rng.randf() > 0.35 else canopy_blue_material
		_add_mesh(
			shrubs_root,
			shrub_mesh,
			shrub_material,
			shrub_position + Vector3(0.0, 0.48, 0.0),
			Vector3.ZERO,
			Vector3(rng.randf_range(0.7, 1.35), rng.randf_range(0.45, 0.85), rng.randf_range(0.7, 1.35))
		)


func _spawn_tree(parent: Node3D, position: Vector3, variant: int, size: float) -> void:
	var tree := Node3D.new()
	tree.position = position
	parent.add_child(tree)
	_add_tree_collider(tree, size)

	match variant:
		0:
			_add_mesh(tree, trunk_mesh, trunk_material, Vector3(0.0, 2.1 * size, 0.0), Vector3.ZERO, Vector3(size, size, size))
			_add_mesh(tree, round_canopy_mesh, canopy_light_material, Vector3(0.0, 4.7 * size, 0.0), Vector3.ZERO, Vector3(1.15 * size, 0.95 * size, 1.15 * size))
			_add_mesh(tree, wide_canopy_mesh, canopy_dark_material, Vector3(0.0, 5.7 * size, 0.0), Vector3.ZERO, Vector3(0.95 * size, 0.7 * size, 0.95 * size))
		1:
			_add_mesh(tree, trunk_mesh, trunk_material, Vector3(0.0, 2.35 * size, 0.0), Vector3.ZERO, Vector3(0.9 * size, 1.2 * size, 0.9 * size))
			_add_mesh(tree, pine_layer_mesh, canopy_dark_material, Vector3(0.0, 3.7 * size, 0.0), Vector3.ZERO, Vector3(1.25 * size, 1.0 * size, 1.25 * size))
			_add_mesh(tree, pine_layer_mesh, canopy_light_material, Vector3(0.0, 4.8 * size, 0.0), Vector3.ZERO, Vector3(0.95 * size, 0.9 * size, 0.95 * size))
			_add_mesh(tree, pine_layer_mesh, canopy_blue_material, Vector3(0.0, 5.7 * size, 0.0), Vector3.ZERO, Vector3(0.68 * size, 0.75 * size, 0.68 * size))
		_:
			_add_mesh(
				tree,
				trunk_mesh,
				trunk_material,
				Vector3(0.0, 1.95 * size, 0.0),
				Vector3(rng.randf_range(-5.0, 5.0), 0.0, rng.randf_range(-7.0, 7.0)),
				Vector3(0.8 * size, 0.95 * size, 0.8 * size)
			)
			_add_mesh(tree, wide_canopy_mesh, canopy_blue_material, Vector3(-0.18 * size, 4.0 * size, 0.1 * size), Vector3.ZERO, Vector3(1.05 * size, 0.8 * size, 1.3 * size))
			_add_mesh(tree, round_canopy_mesh, canopy_dark_material, Vector3(0.35 * size, 4.85 * size, -0.12 * size), Vector3.ZERO, Vector3(0.7 * size, 0.62 * size, 0.7 * size))


func _spawn_ant_swarm(count: int) -> void:
	for _ant_index in range(count):
		_spawn_ant()


func _spawn_food_batch(count: int) -> void:
	for _food_index in range(count):
		_spawn_food()


func _spawn_food() -> void:
	var food = FOOD_SCENE.instantiate()
	food.position = _random_walkable_position(8.0, 6.0)
	food_root.add_child(food)
	food.collected.connect(_on_food_collected)


func _on_food_collected(_pickup: Area3D) -> void:
	var timer := get_tree().create_timer(FOOD_RESPAWN_DELAY)
	timer.timeout.connect(_spawn_food)


func _on_player_health_changed(current: float, maximum: float) -> void:
	health_label.text = "Health: %d / %d" % [roundi(current), roundi(maximum)]


func _on_player_kills_changed(total: int) -> void:
	kills_label.text = "Kills: %d" % total


func _generate_nests() -> void:
	var nests_root := Node3D.new()
	nests_root.name = "AntNests"
	generated_world.add_child(nests_root)
	nest_positions.clear()

	for _nest_index in range(NEST_COUNT):
		var nest_position: Vector3 = _random_walkable_position(12.0, 16.0)
		nest_positions.append(nest_position)
		_add_nest(nests_root, nest_position)


func _start_nest_spawner() -> void:
	var timer := Timer.new()
	timer.wait_time = 4.5
	timer.autostart = true
	timer.one_shot = false
	timer.timeout.connect(_spawn_ant_from_nest)
	add_child(timer)


func _spawn_ant() -> void:
	var ant = ANT_SCENE.instantiate()
	ant.position = _pick_ant_spawn_position()
	enemies_root.add_child(ant)


func _spawn_ant_from_nest() -> void:
	if enemies_root.get_child_count() >= MAX_ANTS:
		return

	_spawn_ant()


func _find_tree_position() -> Vector3:
	for _attempt in range(40):
		var candidate: Vector3 = _random_walkable_position(12.0, 14.0)
		var too_close := false

		for existing_position in occupied_tree_positions:
			if candidate.distance_to(existing_position) < 4.2:
				too_close = true
				break

		if too_close:
			continue

		occupied_tree_positions.append(candidate)
		return candidate

	return _random_walkable_position(12.0, 14.0)


func _random_walkable_position(margin: float, avoid_center_radius: float) -> Vector3:
	for _attempt in range(60):
		var position := Vector3(
			rng.randf_range(-TERRAIN_HALF_EXTENT + margin, TERRAIN_HALF_EXTENT - margin),
			0.0,
			rng.randf_range(-TERRAIN_HALF_EXTENT + margin, TERRAIN_HALF_EXTENT - margin)
		)

		if position.length() < avoid_center_radius:
			continue

		if _is_near_pond(position, 2.5):
			continue

		return position

	return Vector3(avoid_center_radius + margin, 0.0, avoid_center_radius + margin)


func _is_near_pond(position: Vector3, padding: float) -> bool:
	for pond_data in POND_DEFINITIONS:
		var center: Vector3 = pond_data["center"]
		var radius: float = pond_data["radius"]

		if position.distance_to(center) <= radius + padding:
			return true

	return false


func _pick_ant_spawn_position() -> Vector3:
	if nest_positions.is_empty():
		return _random_walkable_position(10.0, 8.0)

	var nest_origin: Vector3 = nest_positions[rng.randi_range(0, nest_positions.size() - 1)]
	var angle: float = rng.randf_range(0.0, TAU)
	var distance: float = rng.randf_range(0.8, 2.4)
	return nest_origin + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)


func _add_mesh(
	parent: Node3D,
	mesh: Mesh,
	material: Material,
	position: Vector3,
	rotation_degrees: Vector3,
	scale: Vector3
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = position
	mesh_instance.rotation_degrees = rotation_degrees
	mesh_instance.scale = scale
	parent.add_child(mesh_instance)
	return mesh_instance


func _add_tree_collider(parent: Node3D, size: float) -> void:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()

	shape.radius = 0.32 * size
	shape.height = 4.0 * size
	collision.shape = shape
	collision.position = Vector3(0.0, 2.0 * size, 0.0)

	body.add_child(collision)
	parent.add_child(body)


func _add_nest(parent: Node3D, position: Vector3) -> void:
	var nest_body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()

	nest_body.position = position + Vector3(0.0, 0.1, 0.0)
	parent.add_child(nest_body)

	mesh_instance.mesh = nest_mesh
	mesh_instance.material_override = bark_light_material
	mesh_instance.position = Vector3(0.0, 0.35, 0.0)
	mesh_instance.scale = Vector3(1.0, 0.7, 1.0)
	nest_body.add_child(mesh_instance)

	shape.radius = 1.2
	shape.height = 0.8
	collision.shape = shape
	collision.position = Vector3(0.0, 0.35, 0.0)
	nest_body.add_child(collision)


func _add_rock_body(
	parent: Node3D,
	mesh: Mesh,
	material: Material,
	position: Vector3,
	rotation_degrees: Vector3,
	scale: Vector3,
	collider_kind: String
) -> StaticBody3D:
	var rock_body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var collision := CollisionShape3D.new()

	rock_body.position = position
	rock_body.rotation_degrees = rotation_degrees
	parent.add_child(rock_body)

	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.scale = scale
	rock_body.add_child(mesh_instance)

	match collider_kind:
		"sphere":
			var sphere_shape := SphereShape3D.new()
			sphere_shape.radius = max(scale.x, scale.y, scale.z)
			collision.shape = sphere_shape
		_:
			var box_shape := BoxShape3D.new()
			if mesh is BoxMesh:
				var box_mesh := mesh as BoxMesh
				box_shape.size = box_mesh.size * scale
			else:
				box_shape.size = Vector3(2.0, 2.0, 2.0) * scale
			collision.shape = box_shape

	rock_body.add_child(collision)
	return rock_body


func _build_forest_ambience_stream() -> AudioStreamWAV:
	var sample_rate := 22050
	var duration := 8.0
	var sample_count := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	for i in sample_count:
		var t := float(i) / float(sample_rate)
		var breeze := sin(TAU * 0.23 * t) * 0.03 + sin(TAU * 0.41 * t) * 0.02
		var leaves := randf_range(-1.0, 1.0) * 0.018
		var birds := 0.0

		if fmod(t, 2.7) < 0.18:
			var local_t := fmod(t, 2.7)
			birds += sin(TAU * (1200.0 + local_t * 420.0) * t) * 0.06 * (1.0 - local_t / 0.18)
		if fmod(t + 0.9, 3.8) < 0.14:
			var local_t_2 := fmod(t + 0.9, 3.8)
			birds += sin(TAU * (1600.0 - local_t_2 * 500.0) * t) * 0.05 * (1.0 - local_t_2 / 0.14)

		var pcm := int(clamp((breeze + leaves + birds) * 32767.0, -32768.0, 32767.0))
		var encoded := pcm & 0xFFFF
		data[i * 2] = encoded & 0xFF
		data[i * 2 + 1] = (encoded >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	stream.data = data
	return stream


func _build_greeting_stream() -> AudioStreamWAV:
	var sample_rate := 22050
	var duration := 1.6
	var sample_count := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	for i in sample_count:
		var t := float(i) / float(sample_rate)
		var tone := 0.0

		if t < 0.28:
			tone = sin(TAU * 420.0 * t) * 0.22 * (1.0 - t / 0.28)
		elif t < 0.58:
			tone = sin(TAU * 520.0 * t) * 0.2 * (1.0 - (t - 0.28) / 0.3)
		elif t < 0.92:
			tone = sin(TAU * 360.0 * t) * 0.22 * (1.0 - (t - 0.58) / 0.34)
		elif t < 1.35:
			tone = sin(TAU * 640.0 * t) * 0.25 * (1.0 - (t - 0.92) / 0.43)

		var pcm := int(clamp(tone * 32767.0, -32768.0, 32767.0))
		var encoded := pcm & 0xFFFF
		data[i * 2] = encoded & 0xFF
		data[i * 2 + 1] = (encoded >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream
