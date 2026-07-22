class_name SplitScreenLayout
extends RefCounted

## Returns up to 4 normalized (0..1) Rect2s describing each player's screen cell.
static func get_quadrant_rects(n: int) -> Array[Rect2]:
	match n:
		1:
			return [Rect2(0, 0, 1, 1)]
		2:
			return [Rect2(0, 0, 0.5, 1), Rect2(0.5, 0, 0.5, 1)]
		3:
			# 1 tall left half (P1) + 2 stacked panels on the right (P2/P3)
			return [Rect2(0, 0, 0.5, 1), Rect2(0.5, 0, 0.5, 0.5), Rect2(0.5, 0.5, 0.5, 0.5)]
		4:
			return [Rect2(0, 0, 0.5, 0.5), Rect2(0.5, 0, 0.5, 0.5), Rect2(0, 0.5, 0.5, 0.5), Rect2(0.5, 0.5, 0.5, 0.5)]
		_:
			return []
