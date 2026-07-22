extends RefCounted
## Creature classes as DATA. Ad-hoc enemy spawns don't scale and the Director will
## generate creatures from data at M2 — so classes live here as data now. Each class
## carries stats, speed, flags (flying), and view hints (color/glyph). spawn() reads
## a class and creates the World object with all its props + tags.

const CLASSES := {
	"goblin": {
		"name": "гоблин", "hp": 6, "atk": 3, "def": 11, "str": 8, "speed": 3,
		"color": [0.75, 0.20, 0.22], "glyph": "circle",
	},
	"bat": {
		"name": "летучая мышь", "hp": 3, "atk": 2, "def": 13, "str": 6, "speed": 8,
		"flying": true, "color": [0.60, 0.40, 0.78], "glyph": "triangle",
	},
	"rat": {
		"name": "крыса", "hp": 2, "atk": 1, "def": 10, "str": 4, "speed": 5,
		"color": [0.55, 0.50, 0.45], "glyph": "circle",
	},
}


static func spawn(prim, cls: String, cell: Vector2i) -> String:
	var props: Dictionary = CLASSES.get(cls, {}).duplicate(true)
	props["class"] = cls
	return prim.spawn(cls, cell, props, ["enemy", "blocking"])


static func exists(cls: String) -> bool:
	return CLASSES.has(cls)
