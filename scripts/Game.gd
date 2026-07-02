extends Node
## Persistent game state (autoload singleton "Game").
## Holds the player's coins, XP/character level, owned turret inventory, which
## turret types are unlocked, how many of each has been bought (for escalating
## price), and the highest game level reached. Saves to user://save.json.

const SAVE_PATH := "user://save.json"

# XP needed to reach the NEXT character level, indexed by current level (1-based).
# Level 1 needs 30 XP to hit level 2, etc. Beyond the list, scale up.
const XP_CURVE := [0, 30, 70, 130, 210, 320, 460, 640]

var coins := 150
var xp := 0
var char_level := 1
var highest_level := 1                 # highest GAME level unlocked/reached

var inventory := {}                    # type_id -> count owned (deployable)
var purchase_counts := {}              # type_id -> times bought (price growth)

signal changed                         # emitted whenever state mutates (UI refresh)


func _ready() -> void:
	load_game()


# ---------- XP / character level ----------
func add_xp(amount: int) -> void:
	xp += amount
	while char_level < XP_CURVE.size() and xp >= _xp_needed_total(char_level + 1):
		char_level += 1
	emit_changed()


func _xp_needed_total(level: int) -> int:
	# Total cumulative XP required to be AT `level`.
	var total := 0
	for i in range(2, level + 1):
		total += (XP_CURVE[i - 1] if i - 1 < XP_CURVE.size() else XP_CURVE[-1] + (i - XP_CURVE.size()) * 220)
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


func emit_changed() -> void:
	changed.emit()


# ---------- Save / load ----------
func save_game() -> void:
	var data := {
		"coins": coins, "xp": xp, "char_level": char_level,
		"highest_level": highest_level, "inventory": inventory,
		"purchase_counts": purchase_counts,
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
