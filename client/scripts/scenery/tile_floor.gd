@tool
extends Node3D
class_name TileFloor

## DIGITAL DELIVERY - Bloco Modular de Piso (tile_default)
## Renderiza malhas tile_default de res://models/tiles/tiles.glb
## Utiliza MultiMeshInstance3D para renderização instanciada em lote via GPU
## e adiciona colisão física StaticBody3D para suporte de caminhada e física.

const TILES_SCENE = preload("res://models/tiles/tiles.glb")

@export var grid_width: int = 4:
	set(val):
		grid_width = max(1, val)
		if is_inside_tree():
			_build_floor()

@export var grid_depth: int = 4:
	set(val):
		grid_depth = max(1, val)
		if is_inside_tree():
			_build_floor()

@export var tile_scale: float = 2.0:
	set(val):
		tile_scale = max(0.5, val)
		if is_inside_tree():
			_build_floor()

var _mmi: MultiMeshInstance3D = null
var _static_body: StaticBody3D = null
var _col_shape: CollisionShape3D = null

func _ready() -> void:
	_build_floor()

func _build_floor() -> void:
	if _mmi == null:
		_mmi = get_node_or_null("MultiMeshInstance")
		if _mmi == null:
			_mmi = MultiMeshInstance3D.new()
			_mmi.name = "MultiMeshInstance"
			add_child(_mmi)

	if _static_body == null:
		_static_body = get_node_or_null("StaticBody3D")
		if _static_body == null:
			_static_body = StaticBody3D.new()
			_static_body.name = "StaticBody3D"
			add_child(_static_body)

	if _col_shape == null:
		_col_shape = _static_body.get_node_or_null("CollisionShape3D")
		if _col_shape == null:
			_col_shape = CollisionShape3D.new()
			_col_shape.name = "CollisionShape3D"
			_static_body.add_child(_col_shape)

	if TILES_SCENE == null:
		return

	var glb_inst = TILES_SCENE.instantiate()
	var mesh_tile: Mesh = null
	var mat_tile: Material = null

	for child in glb_inst.get_children():
		if child is MeshInstance3D and child.name == "tile_default":
			mesh_tile = child.mesh
			if child.material_override:
				mat_tile = child.material_override
			elif child.mesh and child.mesh.get_surface_count() > 0:
				mat_tile = child.mesh.surface_get_material(0)
			break

	glb_inst.queue_free()

	if mesh_tile == null:
		return

	var total_count = grid_width * grid_depth
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh_tile
	multimesh.instance_count = total_count

	var total_w = float(grid_width) * tile_scale
	var total_d = float(grid_depth) * tile_scale
	var half_w = total_w / 2.0
	var half_d = total_d / 2.0

	var idx = 0
	for ix in range(grid_width):
		var x_pos = -half_w + float(ix) * tile_scale
		for iz in range(grid_depth):
			# bounds do tile_default no GLB: X [0..1], Z [-1..0]
			# Com z_pos = -half_d + (iz + 1) * tile_scale, o bloco cobre [-half_d + iz*scale, -half_d + (iz+1)*scale]
			var z_pos = -half_d + float(iz + 1) * tile_scale
			var t = Transform3D()
			t = t.scaled(Vector3(tile_scale, 1.0, tile_scale))
			t.origin = Vector3(x_pos, 0.0, z_pos)
			multimesh.set_instance_transform(idx, t)
			idx += 1

	_mmi.multimesh = multimesh
	if mat_tile:
		_mmi.material_override = mat_tile

	# Atualiza o colisor do chão
	var box = BoxShape3D.new()
	box.size = Vector3(total_w, 0.4, total_d)
	_col_shape.shape = box
	_col_shape.position = Vector3(0, -0.2, 0)
