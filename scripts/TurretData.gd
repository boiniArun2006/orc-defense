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
##   base / gun    sprite keys for the two-part art (static base + turning gun)
##   turn_speed    how fast the gun tracks targets (rad/s)
##   color         accent color (tracers, arcs, UI)
##   blurb         one-line tactical hint shown in the Workshop

const ORDER := ["rifle", "smg", "mgun", "sniper", "bomber"]

# Unlocks are spread far apart on purpose: earning a new weapon should feel
# like a real milestone, and the player has to win with a limited kit first.
const DATA := {
	"rifle": {
		"name": "Rifle", "unlock_level": 1, "base_cost": 60, "cost_growth": 1.22,
		"range": 200.0, "fire_rate": 0.45, "damage": 13.0, "bullet_speed": 620.0,
		"kind": "gun", "can_tap": false, "blast_radius": 0.0,
		"base": "base_a", "gun": "gun_rifle", "turn_speed": 6.0,
		"color": Color(0.55, 0.75, 0.95),
		"blurb": "Reliable all-rounder. Your bread and butter.",
	},
	"smg": {
		"name": "SMG", "unlock_level": 4, "base_cost": 110, "cost_growth": 1.26,
		"range": 140.0, "fire_rate": 0.11, "damage": 3.5, "bullet_speed": 740.0,
		"kind": "gun", "can_tap": false, "blast_radius": 0.0,
		"base": "base_c", "gun": "gun_smg", "turn_speed": 8.0,
		"color": Color(0.7, 0.9, 0.5),
		"blurb": "Short range bullet hose. Melts swarms up close.",
	},
	"mgun": {
		"name": "Machine Gun", "unlock_level": 8, "base_cost": 170, "cost_growth": 1.28,
		"range": 185.0, "fire_rate": 0.18, "damage": 6.0, "bullet_speed": 700.0,
		"kind": "gun", "can_tap": false, "blast_radius": 0.0,
		"base": "base_b", "gun": "gun_mgun", "turn_speed": 5.0,
		"color": Color(0.95, 0.7, 0.35),
		"blurb": "Sustained fire. Anchor it on long straights.",
	},
	"sniper": {
		"name": "Sniper", "unlock_level": 13, "base_cost": 280, "cost_growth": 1.32,
		"range": 360.0, "fire_rate": 1.1, "damage": 75.0, "bullet_speed": 1100.0,
		"kind": "gun", "can_tap": true, "blast_radius": 0.0,
		"base": "base_a", "gun": "gun_sniper", "turn_speed": 3.2,
		"color": Color(0.85, 0.5, 0.85),
		"blurb": "Slow but lethal. Deletes brutes and bosses.",
	},
	"bomber": {
		"name": "Bomber", "unlock_level": 18, "base_cost": 340, "cost_growth": 1.35,
		"range": 250.0, "fire_rate": 1.5, "damage": 42.0, "bullet_speed": 0.0,
		"kind": "bomb", "can_tap": false, "blast_radius": 90.0,
		"base": "base_b", "gun": "gun_bomber", "turn_speed": 4.0,
		"color": Color(0.9, 0.4, 0.35),
		"blurb": "Splash damage. Punishes tight orc packs.",
	},
}


static func get_def(type_id: String) -> Dictionary:
	return DATA[type_id]
