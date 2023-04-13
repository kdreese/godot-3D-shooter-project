@tool
extends Control

const RADIUS := 30.0
const THICKNESS := 6.0

@export_range(0.0, 1.0) var value: float = 0.0

func _draw():
	if value == 0.0:
		return

	var num_points_in_arc := 50
	var points := PackedVector2Array()

	# Draw the outer arc
	for idx in range(num_points_in_arc + 1):
		var angle := value * 2.0 * PI * idx / num_points_in_arc
		var point := (RADIUS + THICKNESS / 2.0) * Vector2(sin(angle), -cos(angle))
		points.push_back(point)

	# Draw the inner arc, in reverse order.
	for idx in range(num_points_in_arc + 1):
		var angle := value * 2.0 * PI * (num_points_in_arc - idx) / num_points_in_arc
		var point := (RADIUS - THICKNESS / 2.0) * Vector2(sin(angle), -cos(angle))
		points.push_back(point)

	var colors = PackedColorArray([Color.from_hsv(0.3 * value, 1.0, 1.0)])

	draw_polygon(points, colors)
