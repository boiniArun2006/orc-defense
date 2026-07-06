extends Node
## Persistent game state (autoload singleton "Game").
## Holds the player's coins, XP/character level, owned turret inventory, which
## turret types are unlocked, how many of each has been bought (for escalating
## price), and the highest game level reached. Saves to user://save.json.

const SAVE_PATH := "user://save.json"

# XP needed to reach the NEXT character level, indexed by current level (1-based).
# Deliberately steep: new turret types (unlocked at char levels 4/8/13/18) must
# feel earned over many battles, not showered on the player by level 5.
const XP_CURVE := [0, 40, 100, 180, 290, 430, 600, 800, 1030, 1290, 1580, 1900]

var coins := 60
var xp := 0
var char_level := 1
var highest_level := 1                 # highest GAME level unlocked/reached

# --- Meta currencies (persist across battles, spent in the Skill Tree) ---
# gems  : blue stones, dropped by killing orcs (the bulk currency)
# orbs  : orange stone-balls, one per LEVEL completed
# cubes : pink cubes, one per BOSS defeated (rare, big-ticket unlocks)
var gems := 0
var orbs := 0
var cubes := 0

var inventory := {}                    # type_id -> count owned (deployable)
var purchase_counts := {}              # type_id -> times bought (price growth)

# settings (audio wired later; persisted now so the Settings screen is ready)
var music_on := true
var sfx_on := true

# where the Loading screen should take us next ("" -> MainMenu)
var next_scene := ""

signal changed                         # emitted whenever state mutates (UI refresh)


func _ready() -> void:
	load_game()
	# first-run gift so the opening battle isn't an instant loss with no turrets
	if not FileAccess.file_exists(SAVE_PATH) and inventory.is_empty():
		inventory = {"rifle": 3}
		save_game()


## Route every scene change through the Loading screen for a proper game feel.
func goto(scene_path: String) -> void:
	next_scene = scene_path
	get_tree().change_scene_to_file("res://scenes/Loading.tscn")


func reset_progress() -> void:
	coins = 60
	xp = 0
	char_level = 1
	highest_level = 1
	inventory = {"rifle": 3}
	purchase_counts = {}
	gems = 0
	orbs = 0
	cubes = 0
	save_game()
	emit_changed()


# ---------- XP / character level ----------
func add_xp(amount: int) -> void:
	xp += amount
	# no artificial cap: past the curve, each level costs +450 XP more
	while xp >= _xp_needed_total(char_level + 1):
		char_level += 1
	emit_changed()


func _xp_needed_total(level: int) -> int:
	# Total cumulative XP required to be AT `level`.
	var total := 0
	for i in range(2, level + 1):
		total += (XP_CURVE[i - 1] if i - 1 < XP_CURVE.size() else XP_CURVE[-1] + (i - XP_CURVE.size()) * 450)
	return total


func xp_into_level() -> int:
	return xp - _xp_needed_total(char_level)


func xp_for_next_level() -> int:
	return _xp_needed_total(char_level + 1) - _xp_needed_total(char_level)


func is_unlocked(type_id: String) -> bool:
	return char_level >= TurretData.DATA[type_id]["unlock_level"]


# ---------- Economy ----------
func price_of(type_id: String) -> int:
	var d: Dictionary = TurretData.DATA[type_id]
	var bought: int = purchase_counts.get(type_id, 0)
	return int(round(d["base_cost"] * pow(d["cost_growth"], bought)))


func can_afford(type_id: String) -> bool:
	return coins >= price_of(type_id)


func buy_turret(type_id: String) -> bool:
	if not is_unlocked(type_id) or not can_afford(type_id):
		return false
	coins -= price_of(type_id)
	purchase_counts[type_id] = purchase_counts.get(type_id, 0) + 1
	inventory[type_id] = inventory.get(type_id, 0) + 1
	save_game()
	emit_changed()
	return true


func owned(type_id: String) -> int:
	return inventory.get(type_id, 0)


func add_coins(amount: int) -> void:
	coins += amount
	emit_changed()


# --- Meta currency earners (see var declarations for what each represents) ---
func add_gems(amount: int) -> void:
	gems += amount
	emit_changed()


func add_orbs(amount: int) -> void:
	orbs += amount
	emit_changed()


func add_cubes(amount: int) -> void:
	cubes += amount
	emit_changed()


func emit_changed() -> void:
	changed.emit()


# ---------- Save / load ----------
func save_game() -> void:
	var data := {
		"coins": coins, "xp": xp, "char_level": char_level,
		"highest_level": highest_level, "inventory": inventory,
		"purchase_counts": purchase_counts,
		"gems": gems, "orbs": orbs, "cubes": cubes,
		"music_on": music_on, "sfx_on": sfx_on,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	coins = int(parsed.get("coins", coins))
	xp = int(parsed.get("xp", xp))
	char_level = int(parsed.get("char_level", char_level))
	highest_level = int(parsed.get("highest_level", highest_level))
	inventory = parsed.get("inventory", {})
	purchase_counts = parsed.get("purchase_counts", {})
	gems = int(parsed.get("gems", 0))
	orbs = int(parsed.get("orbs", 0))
	cubes = int(parsed.get("cubes", 0))
	music_on = bool(parsed.get("music_on", true))
	sfx_on = bool(parsed.get("sfx_on", true))
