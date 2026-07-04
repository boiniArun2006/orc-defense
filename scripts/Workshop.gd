extends Control
## Workshop: buy turrets into your inventory with coins. Each purchase raises the
## next price for that type. Locked types (below your character level) are greyed
## and show the level required. Shows how many of each you own.

var lbl_coins: Label
var rows := {}          # type_id -> {price: Label, owned: Label, buy: Button, name: Label}


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.12, 0.16)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var root := VBoxContainer.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 40
	root.offset_top = 24
	root.offset_right = -40
	root.offset_bottom = -24
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	root.add_child(header)
	var title := Label.new()
	title.text = "WORKSHOP"
	title.add_theme_font_size_override("font_size", 52)
	header.add_child(title)
	lbl_coins = Label.new()
	lbl_coins.add_theme_font_size_override("font_size", 34)
	header.add_child(lbl_coins)

	for type_id in TurretData.ORDER:
		root.add_child(_make_row(type_id))

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(220, 74)
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
	hb.add_child(icon)

	var name_l := Label.new()
	name_l.add_theme_font_size_override("font_size", 30)
	name_l.custom_minimum_size = Vector2(260, 0)
	hb.add_child(name_l)

	var stats := Label.new()
	stats.add_theme_font_size_override("font_size", 22)
	stats.text = "rng %d  rate %.2fs  dmg %d%s" % [
		int(def["range"]), def["fire_rate"], int(def["damage"]),
		("  AoE" if def["kind"] == "bomb" else "")]
	stats.custom_minimum_size = Vector2(360, 0)
	hb.add_child(stats)

	var owned_l := Label.new()
	owned_l.add_theme_font_size_override("font_size", 28)
	owned_l.custom_minimum_size = Vector2(120, 0)
	hb.add_child(owned_l)

	var price_l := Label.new()
	price_l.add_theme_font_size_override("font_size", 28)
	price_l.custom_minimum_size = Vector2(160, 0)
	hb.add_child(price_l)

	var buy := Button.new()
	buy.custom_minimum_size = Vector2(160, 64)
	buy.pressed.connect(_buy.bind(type_id))
	hb.add_child(buy)

	rows[type_id] = {"name": name_l, "owned": owned_l, "price": price_l, "buy": buy}
	return row


func _buy(type_id: String) -> void:
	Game.buy_turret(type_id)   # emits changed -> _refresh


func _refresh() -> void:
	lbl_coins.text = "Coins: %d    (Char Lv %d)" % [Game.coins, Game.char_level]
	for type_id in TurretData.ORDER:
		var def := TurretData.get_def(type_id)
		var r = rows[type_id]
		r["name"].text = def["name"]
		r["owned"].text = "owned: %d" % Game.owned(type_id)
		if not Game.is_unlocked(type_id):
			r["price"].text = "Locked"
			r["buy"].text = "Lv %d" % def["unlock_level"]
			r["buy"].disabled = true
			r["name"].modulate = Color(0.55, 0.55, 0.55)
		else:
			r["name"].modulate = Color.WHITE
			var price: int = Game.price_of(type_id)
			r["price"].text = "%d coins" % price
			r["buy"].text = "BUY"
			r["buy"].disabled = not Game.can_afford(type_id)
