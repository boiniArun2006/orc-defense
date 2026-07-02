class_name TurretData
extends RefCounted
## Static definitions for every turret type. Single source of truth used by the
## Workshop (buying), the battle deploy bar, and Turret.gd (combat behavior).
##
## Fields:
##   name          display name
##   unlock_level  character level required before it can be bought
##   base_cost     workshop coin cost of the first one
##   cost_growth   each purchase multiplies the next price by this
##   range         firing range in px
##   fire_rate     seconds between shots (lower = faster)
##   damage        damage per shot (bomber: per blast)
##   bullet_speed  projectile speed
##   kind          "gun"  -> straight bullets, arc-aimed
##                 "bomb" -> arcing missile with AoE (no aim arc)
##   can_tap       true if the player may toggle tap-to-fire (sniper)
##   blast_radius  AoE radius for bomb kind
##   color         placeholder body color

const ORDER := ["rifle", "mgun", "smg", "sniper", "bomber"]

const DATA := {
	"rifle": {
		"name": "Rifle", "unlock_level": 1, "base_cost": 45, "cost_growth": 1.15,
		"range": 190.0, "fire_rate": 0.55, "damage": 24.0, "bullet_speed": 520.0,
		"kind": "gun", "can_tap": false, "blast_radius": 0.0,
		"color": Color(0.55, 0.75, 0.95),
	},
	"mgun": {
		"name": "Machine Gun", "unlock_level": 2, "base_cost": 80, "cost_growth": 1.18,
		"range": 175.0, "fire_rate": 0.16, "damage": 11.0, "bullet_speed": 560.0,
		"kind": "gun", "can_tap": false, "blast_radius": 0.0,
		"color": Color(0.95, 0.7, 0.35),
	},
	"smg": {
		"name": "SMG", "unlock_level": 3, "base_cost": 60, "cost_growth": 1.16,
		"range": 130.0, "fire_rate": 0.09, "damage": 6.0, "bullet_speed": 600.0,
		"kind": "gun", "can_tap": false, "blast_radius": 0.0,
		"color": Color(0.7, 0.9, 0.5),
	},
	"sniper": {
		"name": "Sniper", "unlock_level": 4, "base_cost": 130, "cost_growth": 1.22,
		"range": 340.0, "fire_rate": 1.4, "damage": 95.0, "bullet_speed": 900.0,
		"kind": "gun", "can_tap": true, "blast_radius": 0.0,
		"color": Color(0.85, 0.5, 0.85),
	},
	"bomber": {
		"name": "Bomber", "unlock_level": 5, "base_cost": 160, "cost_growth": 1.25,
		"range": 240.0, "fire_rate": 2.0, "damage": 55.0, "bullet_speed": 0.0,
		"kind": "bomb", "can_tap": false, "blast_radius": 80.0,
		"color": Color(0.9, 0.4, 0.35),
	},
}


static func get_def(type_id: String) -> Dictionary:
	return DATA[type_id]
