@tool
extends Node3D

## DIGITAL DELIVERY - Poste de Iluminação Estático
## Extrai a malha do poste do tiles.glb e adiciona um OmniLight3D neon no topo.

const TILES_SCENE = preload("res://models/tiles/tiles.glb")

@export var light_color: Color = Color("#00E5FF")
@export var light_energy: float = 2.2
@export var light_range: float = 10.0

func _ready() -> void:
	_setup_post()

func _setup_post() -> void:
	# Remove nós anteriores (para reconstrução no @tool)
	for c in get_children():
		c.queue_free()

	if TILES_SCENE == null:
		return

	var glb_inst = TILES_SCENE.instantiate()
	var lamp_mesh: Mesh = null
	var lamp_material: Material = null

	for child in glb_inst.get_children():
		if child is MeshInstance3D and child.mesh:
			var n = child.name
			if n == "Cube" or n.begins_with("Cube"):
				lamp_mesh = child.mesh
				if child.material_override:
					lamp_material = child.material_override
				elif child.mesh.get_surface_count() > 0:
					lamp_material = child.mesh.surface_get_material(0)
				break
	glb_inst.queue_free()

	if lamp_mesh == null:
		return

	# Malha visual do poste
	var mi := MeshInstance3D.new()
	mi.name = "LampMesh"
	mi.mesh = lamp_mesh
	if lamp_material:
		mi.material_override = lamp_material
	add_child(mi)
	if Engine.is_editor_hint():
		mi.owner = get_tree().edited_scene_root

	# Colisão
	var sb := StaticBody3D.new()
	sb.name = "LampCollision"
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.25
	cyl.height = 2.0
	cs.shape = cyl
	cs.position = Vector3(0, 1.0, 0)
	sb.add_child(cs)
	add_child(sb)
	if Engine.is_editor_hint():
		sb.owner = get_tree().edited_scene_root
		cs.owner = get_tree().edited_scene_root

	# Luz OmniLight3D no topo
	var light := OmniLight3D.new()
	light.name = "LampLight"
	light.position = Vector3(0, 2.0, 0)
	light.light_color = light_color
	light.light_energy = light_energy
	light.omni_range = light_range
	light.omni_attenuation = 1.4
	light.shadow_enabled = true
	add_child(light)
	if Engine.is_editor_hint():
		light.owner = get_tree().edited_scene_root
