extends RefCounted
## Shared helpers for headless tests.

## A w×h tile map with just border walls (interior all floor). Enough for tests
## that need walkability without the specific level geometry.
static func bordered_map(w := 16, h := 10) -> PackedByteArray:
	var t := PackedByteArray()
	t.resize(w * h)
	for y in h:
		for x in w:
			t[y * w + x] = 1 if (x == 0 or y == 0 or x == w - 1 or y == h - 1) else 0
	return t
