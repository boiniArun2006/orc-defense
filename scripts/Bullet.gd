class_name Bullet
extends Node2D
## A homing projectile fired by a gun turret. Uses the Kenney bullet sprite. Lives
## in the camera-transformed world layer; culled by a max lifetime.

var target: Node2D
var speed := 460.0
var damage := 22.0
var _dir := Vector2.RIGHT
var _life := 0.0
const MAX_LIFE := 3.0


func _ready() -> void:
	var spr := Sprite2D.new()
	spr.texture = Assets.tex("bullet")
	spr.scale = Vector2(0.5, 0.5)
	add_child(spr)


func _process(delta: float) -> void:
	_life += delta
	if _life > MAX_LIFE:
		queue_free()
		return
	if is_instance_valid(target):
		var to_target: Vector2 = target.position - position
		var dist := to_target.length()
		if dist < 12.0:
			target.take_damage(damage)
			queue_free()
			return
		_dir = to_target / dist
	position += _dir * speed * delta
