@tool
extends StaticBody3D
class_name WallSegment

## DIGITAL DELIVERY - Segmento Modular de Parede
## Utiliza as malhas de wall (wall_a.01, wall_a.02, wall_b) do tiles.glb
## Fornece geometria visual com materiais PBR e colisão física StaticBody3D.

const TILES_SCENE = preload("res://models/tiles/tiles.glb")

@export_enum("wall_a.01", "wall_a.02", "wall_b") var wall_variant: String = "wall_a.01":
	set(val):
		wall_variant = val
		if is_inside_tree():
			_update_wall()

@export var wall_width: float = 2.0:
	set(val):
		wall_width = max(0.5, val)
		if is_inside_tree():
			_update_wall()

@export var wall_height: float = 2.5:
	set(val):
		wall_height = max(0.5, val)
		if is_inside_tree():
			_update_wall()

var _mesh_inst: MeshInstance3D = null
var _col_shape: CollisionShape3D = null

func _ready() -> void:
	_update_wall()

func _update_wall() -> void:
	if _mesh_inst == null:
		_mesh_inst = get_node_or_null("MeshInstance")
		if _mesh_inst == null:
			_mesh_inst = MeshInstance3D.new()
			_mesh_inst.name = "MeshInstance"
			add_child(_mesh_inst)

	if _col_shape == null:
		_col_shape = get_node_or_null("CollisionShape")
		if _col_shape == null:
			_col_shape = CollisionShape3D.new()
			_col_shape.name = "CollisionShape"
			add_child(_col_shape)

	if TILES_SCENE == null:
		return

	var glb_inst = TILES_SCENE.instantiate()
	var found_mesh: Mesh = null
	var found_mat: Material = null

	for child in glb_inst.get_children():
		if child is MeshInstance3D and child.name == wall_variant:
			found_mesh = child.mesh
			if child.material_override:
				found_mat = child.material_override
			elif child.mesh and child.mesh.get_surface_count() > 0:
				found_mat = child.mesh.surface_get_material(0)
			break

	glb_inst.queue_free()

	if found_mesh:
		_mesh_inst.mesh = found_mesh
		if found_mat:
			_mesh_inst.material_override = found_mat

		# O modelo original no GLB mede 1.0m (X) x 2.0m (Y) x 0.2m (Z), com Z centrado em -0.6m.
		# Centralizamos e escalamos de acordo com wall_width e wall_height.
		var scale_x = wall_width / 1.0
		var scale_y = wall_height / 2.0
		_mesh_inst.scale = Vector3(scale_x, scale_y, 1.0)
		_mesh_inst.position = Vector3(0, 0, 0.6)

	# Atualiza o colisor físico BoxShape3D
	var box = BoxShape3D.new()
	box.size = Vector3(wall_width, wall_height, 0.5)
	_col_shape.shape = box
	_col_shape.position = Vector3(0, wall_height / 2.0, 0)
