extends RigidBody3D
class_name FileCube

## DIGITAL DELIVERY - Cubo de Arquivo 3D Físico
## Ref: Seção 7 e 11 do GDD.md
## Modelo em 45º com arestas aparentes e núcleo de dados que brilha ao ser pego

const PROCESS_SCENE = preload("res://models/process/process.glb")

const CATEGORY_TO_MODEL = {
	"DOCUMENT": "process_docs",
	"SPREADSHEET": "process_sheets",
	"PRESENTATION": "process_slides",
	"IMAGE": "process_image",
	"AUDIO": "process_audio",
	"VIDEO": "process_video",
	"COMPRESSED": "process_zip",
	"WEB": "proccess_internet",
	"EXECUTABLE": "process_config"
}

@export var file_name: String = "relatorio.docx"
@export var extension: String = ".docx"
@export var category: String = "DOCUMENT"

@onready var visual_pivot: Node3D = $VisualPivot
@onready var data_core: MeshInstance3D = $VisualPivot/DataCore
@onready var wireframe_mesh: MeshInstance3D = $VisualPivot/WireframeMesh
@onready var interaction_area: Area3D = $InteractionArea
@onready var floating_label: Label3D = $FloatingLabel

var process_mesh_instance: MeshInstance3D = null
var current_model_name: String = ""
var is_carried: bool = false
var carrier: Node3D = null
var ground_core_color: Color = Color("#00E5FF") # Ciano luminoso no chão
var ground_wire_color: Color = Color("#4FC3F7")

func _ready() -> void:
	# Ajusta física para sensação elástica estilo party-royale
	gravity_scale = 1.6
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4
	
	if visual_pivot == null:
		visual_pivot = get_node_or_null("VisualPivot")
	if data_core == null and visual_pivot:
		data_core = visual_pivot.get_node_or_null("DataCore")
	if wireframe_mesh == null and visual_pivot:
		wireframe_mesh = visual_pivot.get_node_or_null("WireframeMesh")
	if floating_label == null:
		floating_label = get_node_or_null("FloatingLabel")
	if interaction_area == null:
		interaction_area = get_node_or_null("InteractionArea")

	_setup_process_model()
	update_visual_state()

func _physics_process(_delta: float) -> void:
	if is_carried and carrier != null:
		# Quando carregado, segue o ponto de fixação do jogador
		global_position = carrier.global_position
		global_rotation = carrier.global_rotation

func set_file_data(p_name: String, p_ext: String, p_cat: String) -> void:
	file_name = p_name
	extension = p_ext
	category = p_cat
	if is_inside_tree():
		_setup_process_model()
		update_visual_state()

func _setup_process_model() -> void:
	if visual_pivot == null:
		visual_pivot = get_node_or_null("VisualPivot")
	if visual_pivot == null:
		return

	var target_model = "process_default"
	if CATEGORY_TO_MODEL.has(category):
		target_model = CATEGORY_TO_MODEL[category]
	elif category == "SYSTEM":
		target_model = "process_config"

	if target_model == current_model_name and process_mesh_instance != null:
		return

	current_model_name = target_model

	if process_mesh_instance:
		process_mesh_instance.queue_free()
		process_mesh_instance = null

	if PROCESS_SCENE == null:
		return

	var glb_instance = PROCESS_SCENE.instantiate()
	var found_mesh_inst: MeshInstance3D = null

	for child in glb_instance.get_children():
		if child.name == target_model or child.name.begins_with(target_model):
			if child is MeshInstance3D:
				found_mesh_inst = child
				break
			for sub in child.get_children():
				if sub is MeshInstance3D:
					found_mesh_inst = sub
					break
			if found_mesh_inst:
				break

	if found_mesh_inst and found_mesh_inst.mesh:
		process_mesh_instance = MeshInstance3D.new()
		process_mesh_instance.name = "ProcessMesh"
		process_mesh_instance.mesh = found_mesh_inst.mesh

		if found_mesh_inst.material_override:
			process_mesh_instance.material_override = found_mesh_inst.material_override.duplicate()
		for i in range(found_mesh_inst.get_surface_override_material_count()):
			var mat = found_mesh_inst.get_surface_override_material(i)
			if mat:
				process_mesh_instance.set_surface_override_material(i, mat.duplicate())

		# Centraliza o modelo do cubo (Y=0.25) no centro de gravidade do RigidBody
		process_mesh_instance.position = Vector3(0, -0.25, 0)
		process_mesh_instance.scale = Vector3(1.2, 1.2, 1.2)
		visual_pivot.add_child(process_mesh_instance)

		# Oculta malhas procedurais antigas
		if wireframe_mesh:
			wireframe_mesh.visible = false
		if data_core:
			data_core.visible = false

	glb_instance.queue_free()

func set_carried(carried: bool, p_carrier: Node3D = null) -> void:
	is_carried = carried
	carrier = p_carrier
	
	if is_carried:
		freeze = true # Desativa física do RigidBody enquanto está nas mãos
		collision_layer = 0
		collision_mask = 0
	else:
		freeze = false
		collision_layer = 1
		collision_mask = 1
		
	update_visual_state()

func throw(direction: Vector3, force: float = 8.0) -> void:
	set_carried(false, null)
	linear_velocity = direction.normalized() * force + Vector3.UP * 3.5
	angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))

func update_visual_state() -> void:
	if not is_inside_tree():
		return
		
	var target_color = ground_core_color
	var emission_energy = 0.8
	
	# GDD Seção 7: a cor oficial da categoria brilha intensamente quando o jogador carrega o cubo em mãos!
	if is_carried:
		target_color = KnowledgeBase.get_category_color(category)
		emission_energy = 2.5
		
	# Atualiza o material do núcleo de dados
	if data_core and data_core.material_override is StandardMaterial3D:
		var mat = data_core.material_override as StandardMaterial3D
		mat.albedo_color = target_color
		mat.emission_enabled = true
		mat.emission = target_color
		mat.emission_energy_multiplier = emission_energy
		
	# Atualiza as arestas do cubo
	if wireframe_mesh and wireframe_mesh.material_override is StandardMaterial3D:
		var w_mat = wireframe_mesh.material_override as StandardMaterial3D
		w_mat.albedo_color = target_color if is_carried else ground_wire_color
		w_mat.emission_enabled = true
		w_mat.emission = target_color if is_carried else ground_wire_color
		w_mat.emission_energy_multiplier = 1.0 if is_carried else 0.4

	# Atualiza o brilho do modelo autêntico do cubo
	if process_mesh_instance:
		for i in range(process_mesh_instance.get_surface_override_material_count()):
			var p_mat = process_mesh_instance.get_surface_override_material(i)
			if p_mat is StandardMaterial3D:
				p_mat.emission_enabled = true
				p_mat.emission_energy_multiplier = 2.2 if is_carried else 0.9

	# Atualiza rótulo 3D com ícone e nome do arquivo
	if floating_label:
		var icon = KnowledgeBase.get_category_emoji(category)
		floating_label.text = "%s %s" % [icon, file_name]
		if is_carried:
			floating_label.modulate = KnowledgeBase.get_category_color(category)
		else:
			floating_label.modulate = Color(1.0, 1.0, 1.0)
