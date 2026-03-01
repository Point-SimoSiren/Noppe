extends Area3D

signal collected(pickup: Area3D)

@export var heal_amount: float = 18.0

var hover_time: float = 0.0

@onready var visual_root: Node3D = $VisualRoot


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	hover_time += delta
	visual_root.position.y = 0.36 + sin(hover_time * 2.6) * 0.08
	visual_root.rotation.y += delta * 0.9


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	if body.has_method("heal"):
		body.call("heal", heal_amount)

	collected.emit(self)
	queue_free()
