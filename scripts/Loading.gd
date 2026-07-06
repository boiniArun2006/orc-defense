extends Control
## Proper game loading screen, shown on boot and before every battle.
## Full painted backdrop (biome-tinted rolling hills + scattered trees), an
## attack plane that flies across dragging its ground shadow, the level title,
## a rotating tactics tip, and an easing progress bar with a percentage.
## Everything is anchored to the real window size so it centers on any phone.

const TIPS := [
	"Turrets track all around — but only in range. Hug the road.",
	"Runners (yellow) are fast but frail. Short-range SMG fire shreds them.",
	"Brutes (blue) shrug off small bullets. Snipers and bombs punch through armor.",
	"AIR STRIKE: touch the target spot, then drag to point the bombing run.",
	"Corners are gold: turrets there watch two stretches of road at once.",
	"Upgrading a well-placed turret often beats placing a new one.",
	"Losing still earns salvage. Regroup, rebuild, try a new layout.",
	"Spread turret types: no single gun handles every orc.",
	"Bosses hit the gate for massive damage. Do NOT let them walk.",
	"Buy turrets in the Workshop between battles — kills alone won't fund you.",
]

var _t := 0.0
var _dur := 1.8
var _done := false
var _bar_fill: ColorRect
var _bar_w := 640.0
var _pct_lbl: Label
var _plane: Sprite2D
var _plane_shadow: Sprite2D
var _plane_y := 0.0
var _biome := 0


func _ready() -> void:
	var going_to_battle := Game.next_scene.contains("Battle")
	var map: Dictionary = MapData.get_for_level(Game.highest_level)
	_biome = int(map.get("biome", 0)) if going_to_battle else 0

	_build_backdrop()
	_build_plane()
	_build_panel(going_to_battle, map)
	_dur = 1.8 if going_to_battle else 1.2
	resized.connect(func(): queue_redraw())


# ---------- backdrop ----------
func _biome_tones() -> Array:
	match _biome:
		1: return [Color(0.13, 0.11, 0.07), Color(0.35, 0.28, 0.14), Color(0.46, 0.38, 0.19)]  # dunes
		2: return [Color(0.07, 0.09, 0.11), Color(0.16, 0.24, 0.24), Color(0.22, 0.33, 0.28)]  # swamp
		_: return [Color(0.06, 0.09, 0.06), Color(0.14, 0.22, 0.11), Color(0.20, 0.30, 0.15)]  # grass


func _build_backdrop() -> void:
	# hills are painted in _draw() so they always fill the real window
	pass


func _draw() -> void:
	var vs := size
	var tones := _biome_tones()
	draw_rect(Rect2(Vector2.ZERO, vs), tones[0])
	# two layers of rolling hills across the full width
	for layer in range(2):
		var col: Color = tones[1 + layer]
		var base_y: float = vs.y * (0.62 + 0.16 * layer)
		var pts := PackedVector2Array()
		pts.append(Vector2(0, vs.y))
		var seed_off := 3.1 * float(layer + 1)
		var steps := 24
		for i in range(steps + 1):
			var x: float = vs.x * float(i) / float(steps)
			var y: float = base_y + sin(float(i) * 0.7 + seed_off) * 38.0 + cos(float(i) * 0.31 + seed_off) * 22.0
			pts.append(Vector2(x, y))
		pts.append(Vector2(vs.x, vs.y))
		draw_colored_polygon(pts, col)
	# scattered trees along the nearest ridge for depth
	var tree: Texture2D = Assets.tex("tree_big")
	if tree != null:
		for i in range(9):
			var x: float = vs.x * (0.04 + 0.115 * float(i))
			var y: float = vs.y * 0.80 + sin(float(i) * 1.7) * 26.0
			var sc: float = 0.5 + 0.22 * fmod(float(i) * 0.37, 1.0)
			var ts := tree.get_size() * sc
			draw_texture_rect(tree, Rect2(Vector2(x, y) - ts * 0.5, ts), false, Color(0.75, 0.8, 0.72))
	# soft vignette
	draw_rect(Rect2(Vector2.ZERO, Vector2(vs.x, 90)), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(Vector2(0, vs.y - 90), Vector2(vs.x, 90)), Color(0, 0, 0, 0.35))


# ---------- flying plane ----------
func _build_plane() -> void:
	_plane_shadow = Sprite2D.new()
	_plane_shadow.texture = Assets.tex("plane_shadow")
	_plane_shadow.modulate = Color(0, 0, 0, 0.25)
	_plane_shadow.rotation = PI          # art faces LEFT -> flying right
	_plane_shadow.scale = Vector2(1.3, 1.3)
	add_child(_plane_shadow)
	_plane = Sprite2D.new()
	_plane.texture = Assets.tex("plane")
	_plane.rotation = PI                 # art faces LEFT -> flying right
	_plane.scale = Vector2(1.5, 1.5)
	add_child(_plane)
	_plane_y = 0.22


# ---------- center panel ----------
func _build_panel(going_to_battle: bool, map: Dictionary) -> void:
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vb.grow_vertical = Control.GROW_DIRECTION_BOTH
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 16)
	add_child(vb)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if going_to_battle:
		title.text = "LEVEL %d — %s" % [Game.highest_level, MapData.biome_name(map["biome"])]
	else:
		title.text = "ORC DEFENSE"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.42))
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.04))
	vb.add_child(title)

	if going_to_battle and Game.highest_level % 5 == 0:
		var warn := Label.new()
		warn.text = "!!  BOSS LEVEL  !!"
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		warn.add_theme_font_size_override("font_size", 34)
		warn.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
		warn.add_theme_constant_override("outline_size", 6)
		warn.add_theme_color_override("font_outline_color", Color(0.1, 0.02, 0.02))
		vb.add_child(warn)

	# tip sits in its own parchment strip so it reads as deliberate UI
	var tip_panel := PanelContainer.new()
	var tip_sb := StyleBoxFlat.new()
	tip_sb.bg_color = Color(0.09, 0.08, 0.06, 0.82)
	tip_sb.border_color = Color(0.45, 0.37, 0.25)
	tip_sb.set_border_width_all(2)
	tip_sb.set_corner_radius_all(12)
	tip_sb.content_margin_left = 22
	tip_sb.content_margin_right = 22
	tip_sb.content_margin_top = 10
	tip_sb.content_margin_bottom = 10
	tip_panel.add_theme_stylebox_override("panel", tip_sb)
	vb.add_child(tip_panel)
	var tip := Label.new()
	tip.text = "TIP:  " + TIPS[randi() % TIPS.size()]
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(760, 0)
	tip.add_theme_font_size_override("font_size", 25)
	tip.add_theme_color_override("font_color", Color(0.9, 0.87, 0.75))
	tip_panel.add_child(tip)

	# progress bar trough + fill + percentage
	var bar_bg := Panel.new()
	bar_bg.custom_minimum_size = Vector2(_bar_w, 30)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.04, 0.04, 0.9)
	sb.border_color = Color(0.5, 0.42, 0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(15)
	bar_bg.add_theme_stylebox_override("panel", sb)
	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(_bar_w, 42)
	center.add_child(bar_bg)
	vb.add_child(center)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(0.98, 0.8, 0.3)
	_bar_fill.position = Vector2(5, 5)
	_bar_fill.size = Vector2(0, 20)
	bar_bg.add_child(_bar_fill)

	_pct_lbl = Label.new()
	_pct_lbl.text = "0%"
	_pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pct_lbl.add_theme_font_size_override("font_size", 22)
	_pct_lbl.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65))
	vb.add_child(_pct_lbl)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var pct: float = clamp(_t / _dur, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - pct, 2.2)
	_bar_fill.size.x = (_bar_w - 10.0) * eased
	_pct_lbl.text = "%d%%" % int(eased * 100.0)
	# plane sweeps left -> right across the top third, shadow trailing below
	var vs := size
	var px: float = lerp(-120.0, vs.x + 120.0, eased)
	var py: float = vs.y * _plane_y + sin(_t * 6.0) * 10.0
	_plane.position = Vector2(px, py)
	_plane.rotation = PI + sin(_t * 6.0) * 0.06
	_plane_shadow.position = Vector2(px + 26, py + 46)
	_plane_shadow.rotation = _plane.rotation
	if pct >= 1.0:
		_done = true
		var target := Game.next_scene
		Game.next_scene = ""
		if target == "":
			target = "res://scenes/MainMenu.tscn"
		get_tree().change_scene_to_file(target)
