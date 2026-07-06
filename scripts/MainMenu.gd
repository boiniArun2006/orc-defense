extends Control
## Title screen: layered painted backdrop, logo banner, stats card, big menu
## buttons — and a little orc horde marching across the bottom for life.

var lbl_stats: Label
var _orcs: Array = []
var _orc_layer: Node2D


func _ready() -> void:
	# painted backdrop: deep green gradient + soft "hills"
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.11, 0.09)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)
	var back := _Backdrop.new()
	add_child(back)

	# marching orcs strip (behind the UI) — positioned in _process off real size
	_orc_layer = Node2D.new()
	add_child(_orc_layer)
	for i in range(6):
		var s := Sprite2D.new()
		s.texture = Assets.tex("orc")
		s.modulate = Color(0.7, 1.15, 0.6)
		s.scale = Vector2(2.4, 2.4)
		s.position = Vector2(-80.0 - i * 220.0, 0.0)
		_orc_layer.add_child(s)
		_orcs.append(s)

	var vb := VBoxContainer.new()
	vb.anchor_left = 0.5
	vb.anchor_right = 0.5
	vb.anchor_top = 0.5
	vb.anchor_bottom = 0.5
	vb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vb.grow_vertical = Control.GROW_DIRECTION_BOTH
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 16)
	add_child(vb)

	vb.add_child(_make_logo())

	var stats_panel := PanelContainer.new()
	var stats_row := HBoxContainer.new()
	stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_row.add_theme_constant_override("separation", 10)
	stats_panel.add_child(stats_row)
	var coin_icon := TextureRect.new()
	coin_icon.texture = Assets.tex("coin")
	coin_icon.custom_minimum_size = Vector2(30, 30)
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stats_row.add_child(coin_icon)
	lbl_stats = Label.new()
	lbl_stats.add_theme_font_size_override("font_size", 26)
	stats_row.add_child(lbl_stats)
	vb.add_child(stats_panel)

	var play := Button.new()
	play.text = "PLAY  —  LEVEL %d" % Game.highest_level
	play.custom_minimum_size = Vector2(420, 92)
	play.add_theme_font_size_override("font_size", 34)
	play.pressed.connect(func(): Game.goto("res://scenes/Battle.tscn"))
	vb.add_child(play)
	vb.add_child(_menu_button("WORKSHOP", "res://scenes/Workshop.tscn", Vector2(420, 74)))
	vb.add_child(_menu_button("SETTINGS", "res://scenes/Settings.tscn", Vector2(420, 74)))

	_refresh()
	Game.changed.connect(_refresh)


func _process(delta: float) -> void:
	# the horde never stops marching, along the real bottom on any aspect ratio
	var w := size.x
	var ground_y := size.y - 88.0
	for s in _orcs:
		s.position.x += 60.0 * delta
		s.position.y = ground_y - abs(sin(s.position.x * 0.05)) * 5.0
		if s.position.x > w + 100.0:
			s.position.x = -100.0


func _make_logo() -> Control:
	# a banner panel with the title flanked by an orc and a plane sprite
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)

	row.add_child(_sprite_icon("orc", 84, Color(0.7, 1.15, 0.6)))

	var title := Label.new()
	title.text = "ORC DEFENSE"
	title.add_theme_font_size_override("font_size", 78)
	title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.42))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color(0.15, 0.09, 0.05))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(title)

	row.add_child(_sprite_icon("plane", 84, Color(1, 1, 1)))
	return panel


func _sprite_icon(key: String, size: int, tint: Color) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = Assets.tex(key)
	tr.custom_minimum_size = Vector2(size, size)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.modulate = tint
	return tr


func _menu_button(text: String, scene: String, size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.pressed.connect(func(): get_tree().change_scene_to_file(scene))
	return b


func _refresh() -> void:
	lbl_stats.text = "%d      Character Lv %d    XP %d/%d" % [
		Game.coins, Game.char_level, Game.xp_into_level(), Game.xp_for_next_level()]


## Simple painted hills + sky glow so the title screen has depth without art.
class _Backdrop:
	extends Control

	func _ready() -> void:
		anchor_right = 1.0
		anchor_bottom = 1.0
		queue_redraw()

	func _process(_d: float) -> void:
		queue_redraw()   # keep filling the real (post-stretch) rect

	func _draw() -> void:
		var sz := size                       # actual window size, any aspect
		var w := sz.x
		var h := sz.y
		var ground_y := h - 65.0
		# horizon glow
		for i in range(6):
			var a := 0.05 - i * 0.008
			draw_rect(Rect2(0, h * 0.25 + i * 40, w, 40), Color(0.9, 0.8, 0.4, max(a, 0.0)))
		# rolling hills, three parallax tones (relative to height)
		_hill(h * 0.60, 90.0, w, h, Color(0.10, 0.17, 0.10))
		_hill(h * 0.71, 70.0, w, h, Color(0.12, 0.21, 0.12))
		_hill(h * 0.80, 50.0, w, h, Color(0.14, 0.25, 0.13))
		# ground strip the orcs march on, pinned to the real bottom
		draw_rect(Rect2(0, ground_y, w, 65), Color(0.16, 0.13, 0.09))
		draw_rect(Rect2(0, ground_y - 5, w, 8), Color(0.22, 0.18, 0.12))

	func _hill(base_y: float, amp: float, w: float, h: float, col: Color) -> void:
		var pts := PackedVector2Array()
		pts.append(Vector2(0, h))
		var n := int(w / 40.0) + 1
		for i in range(n + 1):
			var x := i * 40.0
			pts.append(Vector2(x, base_y - sin(x * 0.008 + base_y) * amp))
		pts.append(Vector2(w, h))
		draw_colored_polygon(pts, col)
