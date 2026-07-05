class_name StrikePlane
extends Node2D
## An attack plane called in by the AIR STRIKE ability. It flies in from
## off-screen along the line the player dragged, releases bombs evenly across
## that corridor, and exits the far side. A ground shadow flies offset beneath
## it for a real sense of altitude, and the plane gently rocks while flying.

const SPEED := 720.0
const ENTRY_DIST := 950.0        # spawn this far before the corridor start
const EXIT_DIST := 900.0         # despawn this far past the corridor end

var battle: Node
var from_pos := Vector2.ZERO     # corridor start (world)
var to_pos := Vector2.ZERO       # corridor end (world)
var bombs := 5
var damage := 50.0
var blast_radius := 80.0
var lateral := 0.0               # sideways offset so twin planes don't overlap

var _dir := Vector2.RIGHT
var _travelled := 0.0
var _drop_at: Array = []         # travel distances at which to release bombs
var _next_drop := 0
var _spr: Sprite2D
var _shadow: Sprite2D
var _t := 0.0


func _ready() -> void:
	_dir = (to_pos - from_pos).normalized()
	var side := Vector2(-_dir.y, _dir.x) * lateral
	from_pos += side
	to_pos += side
	position = from_pos - _dir * ENTRY_DIST
	var corridor: float = from_pos.distance_to(to_pos)
	# bombs release evenly across the dragged corridor
	for i in range(bombs):
		var frac := (float(i) + 0.5) / float(bombs)
		_drop_at.append(ENTRY_DIST + corridor * frac)

	_shadow = Sprite2D.new()
	_shadow.texture = Assets.tex("plane_shadow")
	_shadow.modulate = Color(0, 0, 0, 0.30)
	_shadow.position = Vector2(22, 34)
	_shadow.rotation = _dir.angle() + PI / 2.0
	_shadow.scale = Vector2(1.15, 1.15)
	add_child(_shadow)

	_spr = Sprite2D.new()
	_spr.texture = Assets.tex("plane")
	_spr.rotation = _dir.angle() + PI / 2.0   # art points up
	_spr.scale = Vector2(1.35, 1.35)
	add_child(_spr)


func _process(delta: float) -> void:
	var step := SPEED * delta
	_travelled += step
	position += _dir * step
	# gentle banking wobble so the flight feels alive
	_t += delta
	var wob := sin(_t * 9.0) * 0.05
	_spr.rotation = _dir.angle() + PI / 2.0 + wob
	_shadow.rotation = _spr.rotation
	# release bombs as we cross their drop distances
	while _next_drop < _drop_at.size() and _travelled >= float(_drop_at[_next_drop]):
		_release_bomb()
		_next_drop += 1
	var total: float = ENTRY_DIST + from_pos.distance_to(to_pos) + EXIT_DIST
	if _travelled >= total:
		queue_free()


func _release_bomb() -> void:
	if battle == null or not is_instance_valid(battle) or battle.finished:
		return
	var m := Missile.new()
	m.battle = battle
	m.position = position
	# bombs land a touch ahead of the plane with a little scatter
	m.target_pos = position + _dir * 120.0 + Vector2(randf_range(-30, 30), randf_range(-30, 30))
	m.speed = 620.0
	m.damage = damage
	m.blast_radius = blast_radius
	battle.world.add_child(m)
