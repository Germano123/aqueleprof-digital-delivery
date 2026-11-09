extends Node3D
class_name ArenaPropsBuilder

## DIGITAL DELIVERY - Construtor de Cenário e Props Modulares
## Utiliza res://models/tiles/tiles.glb para gerar:
## 1. Paredes de contenção perimetral (wall_a.01, wall_a.02, wall_b)
## 2. Faixas de piso organizado e esteiras (tile_organized, tile_move)
## Nota: Os postes de iluminação agora são nós estáticos na cena (LampPost instances).

const TILES_SCENE = preload("res://models/tiles/tiles.glb")

# Malhas cacheadas do tiles.glb
var mesh_wall_a1: Mesh = null
var mesh_wall_a2: Mesh = null
var mesh_wall_b: Mesh = null
var mesh_tile_default: Mesh = null
var mesh_tile_org: Mesh = null
var mesh_tile_move: Mesh = null
var mesh_tile_damaged: Mesh = null

var mat_tiles: Material = null
var mat_tile_default: Material = null

func _ready() -> void:
	_extract_meshes()

func _extract_meshes() -> void:
	if TILES_SCENE == null:
		return

	var glb_inst = TILES_SCENE.instantiate()
	for child in glb_inst.get_children():
		if child is MeshInstance3D and child.mesh:
			var n = child.name
			if n == "wall_a.01":
				mesh_wall_a1 = child.mesh
			elif n == "wall_a.02":
				mesh_wall_a2 = child.mesh
			elif n == "wall_b":
				mesh_wall_b = child.mesh
			elif n == "tile_default":
				mesh_tile_default = child.mesh
				if child.material_override:
					mat_tile_default = child.material_override
				elif child.mesh.get_surface_count() > 0:
					mat_tile_default = child.mesh.surface_get_material(0)
			# Os demais tiles coloridos abaixo são extraídos e reservados para a mecânica de 'otimização de disco'
			elif n == "tile_organized":
				mesh_tile_org = child.mesh
			elif n == "tile_move":
				mesh_tile_move = child.mesh
			elif n == "tile_damaged":
				mesh_tile_damaged = child.mesh

			if mat_tiles == null and child.material_override:
				mat_tiles = child.material_override

	glb_inst.queue_free()

func _build_perimeter_walls() -> void:
	var wall_meshes = [mesh_wall_a1, mesh_wall_a2, mesh_wall_b]
	wall_meshes = wall_meshes.filter(func(m): return m != null)
	if wall_meshes.is_empty():
		return

	var walls_group = Node3D.new()
	walls_group.name = "PerimeterWallsGroup"
	add_child(walls_group)

	# Borda da placa-mãe (aproximadamente 34m do centro)
	var boundary = 34.0
	var step = 2.0 # Cada módulo de parede cobre ~2m de extensão com escala
	var wall_idx = 0

	# 4 Lados da arena: Norte, Sul, Leste, Oeste
	# 1. Borda Norte (Z = -boundary)
	for x in range(int(-boundary), int(boundary), int(step)):
		var w = _create_wall_segment(Vector3(x, 0, -boundary), 0.0, wall_meshes[wall_idx % wall_meshes.size()])
		walls_group.add_child(w)
		wall_idx += 1

	# 2. Borda Sul (Z = boundary)
	for x in range(int(-boundary), int(boundary), int(step)):
		var w = _create_wall_segment(Vector3(x, 0, boundary), PI, wall_meshes[wall_idx % wall_meshes.size()])
		walls_group.add_child(w)
		wall_idx += 1

	# 3. Borda Leste (X = boundary)
	for z in range(int(-boundary), int(boundary), int(step)):
		var w = _create_wall_segment(Vector3(boundary, 0, z), -PI / 2.0, wall_meshes[wall_idx % wall_meshes.size()])
		walls_group.add_child(w)
		wall_idx += 1

	# 4. Borda Oeste (X = -boundary)
	for z in range(int(-boundary), int(boundary), int(step)):
		var w = _create_wall_segment(Vector3(-boundary, 0, z), PI / 2.0, wall_meshes[wall_idx % wall_meshes.size()])
		walls_group.add_child(w)
		wall_idx += 1

func _create_wall_segment(pos: Vector3, rot_y: float, mesh_ref: Mesh) -> Node3D:
	var node = Node3D.new()
	node.position = pos
	node.rotation.y = rot_y

	var mi = MeshInstance3D.new()
	mi.mesh = mesh_ref
	mi.scale = Vector3(2.0, 1.5, 2.0) # Ajusta altura para 3.0m
	if mat_tiles:
		mi.material_override = mat_tiles
	node.add_child(mi)

	var sb = StaticBody3D.new()
	var cs = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(2.0, 3.0, 0.6)
	cs.shape = box
	cs.position = Vector3(0, 1.5, 0)
	sb.add_child(cs)
	node.add_child(sb)

	return node

func _build_default_tile_floor() -> void:
	if mesh_tile_default == null:
		return

	# Cobre a área interior da placa-mãe de parede a parede (-32m a +32m) com tiles_default
	# Cada tile_default mede 1x0.2x1m (bounds: X [0..1], Z [-1..0]).
	# Escalado para 2x1x2m, cada tile cobre X [x..x+2] e Z [z-2..z].
	var x_coords: Array[float] = []
	for x in range(-32, 32, 2):
		x_coords.append(float(x))

	var z_coords: Array[float] = []
	for z in range(-30, 34, 2):
		z_coords.append(float(z))

	var total_instances = x_coords.size() * z_coords.size()

	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh_tile_default
	multimesh.instance_count = total_instances

	var idx = 0
	for x in x_coords:
		for z in z_coords:
			var t = Transform3D()
			t = t.scaled(Vector3(2.0, 1.0, 2.0))
			t.origin = Vector3(x, 0.01, z)
			multimesh.set_instance_transform(idx, t)
			idx += 1

	var mmi = MultiMeshInstance3D.new()
	mmi.name = "FloorTilesDefaultMultiMesh"
	mmi.multimesh = multimesh
	if mat_tile_default:
		mmi.material_override = mat_tile_default
	add_child(mmi)

# Função reservada para a futura mecânica de 'otimização de disco' (desfragmentação)
func setup_disk_optimization_tiles(_damaged_tiles: Array, _optimized_tiles: Array) -> void:
	# Quando a mecânica for ativada, mesh_tile_damaged, mesh_tile_org e mesh_tile_move
	# serão instanciados para indicar blocos fragmentados e organizados.
	pass

