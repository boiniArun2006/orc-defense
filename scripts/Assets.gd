class_name Assets
extends RefCounted
## Central texture loader with a cache, so every unit shares one Texture2D per
## file instead of reloading. Pixel-art sprites are sourced from Kenney (CC0):
##   - Tower Defense (Top-Down): turrets, projectiles, flames, ground
##   - Tiny Dungeon: orc / boss creatures
## See assets/CREDITS.md.

static var _cache := {}

const SPRITES := {
	"orc": "res://assets/sprites/orc.png",
	"orc_boss": "res://assets/sprites/orc_boss.png",
	"rifle": "res://assets/sprites/turret_rifle.png",
	"mgun": "res://assets/sprites/turret_mgun.png",
	"smg": "res://assets/sprites/turret_smg.png",
	"sniper": "res://assets/sprites/turret_sniper.png",
	"bomber": "res://assets/sprites/turret_bomber.png",
	"bullet": "res://assets/sprites/bullet.png",
	"rocket": "res://assets/sprites/rocket.png",
	"flame_1": "res://assets/sprites/flame_1.png",
	"flame_2": "res://assets/sprites/flame_2.png",
	"flame_3": "res://assets/sprites/flame_3.png",
	"flame_4": "res://assets/sprites/flame_4.png",
	"grass": "res://assets/sprites/grass.png",
	"dirt": "res://assets/sprites/dirt.png",
	"sand": "res://assets/sprites/sand.png",
	"stone": "res://assets/sprites/stone.png",
	"path_grass": "res://assets/sprites/path_grass.png",
	"path_sand": "res://assets/sprites/path_sand.png",
	"path_stone": "res://assets/sprites/path_stone.png",
	"bush": "res://assets/sprites/bush.png",
	"tree": "res://assets/sprites/tree.png",
	"rock": "res://assets/sprites/rock.png",
	"rock2": "res://assets/sprites/rock2.png",
	"gate": "res://assets/sprites/gate.png",
}


# biome -> [ground tile key, path tile key]
const BIOME_TILES := {
	"grass": ["grass", "path_grass"],
	"desert": ["sand", "path_sand"],
	"stone": ["stone", "path_stone"],
}


static func tex(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var path: String = SPRITES.get(key, "")
	var t: Texture2D = load(path) if path != "" and ResourceLoader.exists(path) else null
	_cache[key] = t
	return t


static func turret_tex(type_id: String) -> Texture2D:
	return tex(type_id)
