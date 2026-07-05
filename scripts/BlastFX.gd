class_name BlastFX
extends Node2D
## Short-lived explosion: the 4 Kenney flame frames kept tight to the impact
## point, plus an expanding shockwave ring that communicates the true blast
## radius (the old version scaled the fireball to the full radius — too big).

var radius := 80.0
var _t := 0.0
const LIFE := 0.34
var _spr: Sprite2D
var _frames: Array = []


func _ready() -> void:
	_frames = [Assets.tex("flame_1"), Assets.tex("flame_2"), Assets.tex("flame_3"), Assets.tex("flame_4")]
	_spr = Sprite2D.new()
	_spr.texture = _frames[0]
	# keep the fireball compact (~1.2x radius across), let the ring show the AoE
	var s := (radius * 1.2) / 32.0
	_spr.scale = Vector2(s, s)
	add_child(_spr)


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	var k: float = clamp(_t / LIFE, 0.0, 1.0)
	var frame: int = clamp(int(k * _frames.size()), 0, _frames.size() - 1)
	_spr.texture = _frames[frame]
	_spr.modulate.a = 1.0 - k * 0.5
	queue_redraw()


func _draw() -> void:
	# shockwave ring: expands to the blast radius and fades out
	var k: float = clamp(_t / LIFE, 0.0, 1.0)
	draw_arc(Vector2.ZERO, radius * (0.45 + 0.55 * k), 0.0, TAU, 40,
		Color(1.0, 0.8, 0.4, 0.55 * (1.0 - k)), 4.0)
