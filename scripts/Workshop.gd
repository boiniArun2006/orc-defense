extends Control
## Workshop: buy turrets into your inventory with coins. Each purchase raises the
## next price for that type. Locked types (below your character level) are greyed
## and show the level required. Shows how many of each you own plus a one-line
## tactical blurb, so buying is a real decision.

var lbl_coins: Label
var rows := {}          # type_id -> {price: Label, owned: Label, buy: Button, name: Label, blurb: Label}


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.10, 0.12)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var root := VBoxContainer.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 40
	root.offset_top = 20
	root.offset_right = -40
	root.offset_bottom = -20
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	root.add_child(header)
	var title := Label.new()
	title.text = "WORKSHOP"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.42))
	header.add_child(title)
	var coin_icon := TextureRect.new()
	coin_icon.texture = Assets.tex("coin")
	coin_icon.custom_minimum_size = Vector2(34, 34)
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(coin_icon)
	lbl_coins = Label.new()
	lbl_coins.add_theme_font_size_override("font_size", 32)
	lbl_coins.add_theme_color_override("font_color", Color(0.98, 0.86, 0.42))
	header.add_child(lbl_coins)

	for type_id in TurretData.ORDER:
		root.add_child(_make_row(type_id))

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(220, 70)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	root.add_child(back)

	_refresh()
	Game.changed.connect(_refresh)


func _make_row(type_id: String) -> Control:
	var def := TurretData.get_def(type_id)
	var row := PanelContainer.new()
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	row.add_child(hb)

	var icon := TextureRect.new()
	icon.texture = Assets.turret_tex(type_id)
	icon.custom_minimum_size = Vector2(56, 56)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hb.add_child(icon)

	var name_box := VBoxContainer.new()
	name_box.custom_minimum_size = Vector2(430, 0)
	name_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(name_box)
	var name_l := Label.new()
	name_l.add_theme_font_size_override("font_size", 28)
	name_box.add_child(name_l)
	var blurb_l := Label.new()
	blurb_l.add_theme_font_size_override("font_size", 18)
	blurb_l.add_theme_color_override("font_color", Color(0.75, 0.72, 0.62))
	blurb_l.text = def.get("blurb", "")
	name_box.add_child(blurb_l)

	var stats := Label.new()
	stats.add_theme_font_size_override("font_size", 20)
	stats.text = "rng %d   rate %.2fs   dmg %d%s" % [
		int(def["range"]), def["fire_rate"], int(def["damage"]),
		("   AoE" if def["kind"] == "bomb" else "")]
	stats.custom_minimum_size = Vector2(320, 0)
	hb.add_child(stats)

	var owned_l := Label.new()
	owned_l.add_theme_font_size_override("font_size", 26)
	owned_l.custom_minimum_size = Vector2(110, 0)
	hb.add_child(owned_l)

	var price_l := Label.new()
	price_l.add_theme_font_size_override("font_size", 26)
	price_l.custom_minimum_size = Vector2(150, 0)
	hb.add_child(price_l)

	var buy := Button.new()
	buy.custom_minimum_size = Vector2(170, 60)
	buy.pressed.connect(_buy.bind(type_id))
	hb.add_child(buy)

	rows[type_id] = {"name": name_l, "blurb": blurb_l, "owned": owned_l, "price": price_l, "buy": buy, "icon": icon}
	return row


func _buy(type_id: String) -> void:
	Game.buy_turret(type_id)   # emits changed -> _refresh


func _refresh() -> void:
	lbl_coins.text = "%d      Char Lv %d" % [Game.coins, Game.char_level]
	for type_id in TurretData.ORDER:
		var def := TurretData.get_def(type_id)
		var r = rows[type_id]
		r["name"].text = def["name"]
		r["owned"].text = "owned: %d" % Game.owned(type_id)
		if not Game.is_unlocked(type_id):
			r["price"].text = "LOCKED"
			r["buy"].text = "Char Lv %d" % def["unlock_level"]
			r["buy"].disabled = true
			r["name"].modulate = Color(0.55, 0.55, 0.55)
			r["icon"].modulate = Color(0.3, 0.3, 0.3)
		else:
			r["name"].modulate = Color.WHITE
			r["icon"].modulate = Color.WHITE
			var price: int = Game.price_of(type_id)
			r["price"].text = "%d coins" % price
			r["buy"].text = "BUY"
			r["buy"].disabled = not Game.can_afford(type_id)
