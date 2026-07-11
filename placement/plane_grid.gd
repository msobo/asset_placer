class_name PlaneGrid
extends RefCounted


static func get_axes(normal: Vector3) -> Array[Vector3]:
	var n := normal.normalized()
	var tangent := Vector3.UP.cross(n).normalized()
	if tangent.length() < 0.001:
		tangent = Vector3.RIGHT.cross(n).normalized()
	var bitangent := n.cross(tangent).normalized()
	return [tangent, bitangent]


static func snap_position(position: Vector3, normal: Vector3, grid_step: Vector2) -> Vector3:
	var n := normal.normalized()
	var axes := get_axes(n)
	var tangent: Vector3 = axes[0]
	var bitangent: Vector3 = axes[1]
	var cell := world_to_cell(position, n, grid_step)
	return tangent * cell.x * grid_step.x + bitangent * cell.y * grid_step.y + n * n.dot(position)


static func world_to_cell(position: Vector3, normal: Vector3, grid_step: Vector2) -> Vector2i:
	var axes := get_axes(normal)
	return Vector2i(
		roundi((axes[0] as Vector3).dot(position) / grid_step.x),
		roundi((axes[1] as Vector3).dot(position) / grid_step.y)
	)


static func cell_to_world(
	cell: Vector2i, plane_options: PlaneOptions, grid_step: Vector2
) -> Vector3:
	var n := plane_options.normal.normalized()
	var axes := get_axes(n)
	return (
		(axes[0] as Vector3) * cell.x * grid_step.x
		+ (axes[1] as Vector3) * cell.y * grid_step.y
		+ n * n.dot(plane_options.origin)
	)


static func raster_line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [from]
	var dx := to.x - from.x
	var dy := to.y - from.y
	var nx := absi(dx)
	var ny := absi(dy)
	var sign_x := signi(dx)
	var sign_y := signi(dy)
	var x := from.x
	var y := from.y
	var ix := 0
	var iy := 0
	while ix < nx or iy < ny:
		var decision := (1 + 2 * ix) * ny - (1 + 2 * iy) * nx
		if decision == 0:
			x += sign_x
			y += sign_y
			ix += 1
			iy += 1
		elif decision < 0:
			x += sign_x
			ix += 1
		else:
			y += sign_y
			iy += 1
		cells.append(Vector2i(x, y))
	return cells


static func rectangle(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(mini(from.x, to.x), maxi(from.x, to.x) + 1):
		for y in range(mini(from.y, to.y), maxi(from.y, to.y) + 1):
			cells.append(Vector2i(x, y))
	return cells
