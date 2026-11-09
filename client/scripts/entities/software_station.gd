@tool
extends Node3D
class_name SoftwareStation

## DIGITAL DELIVERY - Estação de Software no Mapa do Computador
## Ref: Seções 6, 10 e 13 do GDD.md
## Estrutura com modelo 3D autêntico e zona de entrega de arquivos

const APPS_SCENE = preload("res://models/apps/apps.glb")

# Mapeamento do software_id para o nó correspondente dentro do apps.glb
const SOFTWARE_TO_MODEL = {
	"text_editor": "app_docs",
	"calc_sheet": "app_sheets",
	"slide_presentation": "app_slides",
	"image_editor": "app_image",
	"audio_player": "app_music",
	"video_player": "app_video",
	"archive_manager": "app_zip",
	"web_browser": "app_explorer",
	"system_runner": "app_config",
	"pdf_viewer": "app_docs"
}

@export var software_id: String = "text_editor":
	set(val):
		software_id = val
		if is_inside_tree():
			_update_station_info()
			_setup_app_model()

@export var app_model_name: String = "":
	set(val):
		app_model_name = val
		if is_inside_tree():
			_setup_app_model()

@export var station_name: String = "Editor de Texto"
@export var station_color: Color = Color("#3498DB")

@onready var label_name: Label3D = $SignPivot/LabelName
@onready var drop_zone: Area3D = $DropZoneArea
@onready var beacon_mesh: MeshInstance3D = $DropZoneArea/BeaconMesh
@onready var building_mesh: MeshInstance3D = $BuildingMesh
@onready var ejection_point: Marker3D = $EjectionPoint
@onready var firewall_barrier: FirewallBarrier = get_node_or_null("FirewallBarrier")

var cooldown_timer: float = 0.0

func is_firewall_active() -> bool:
	if firewall_barrier and is_instance_valid(firewall_barrier):
		return firewall_barrier.is_blocking()
	return false

func activate_firewall() -> bool:
	if firewall_barrier and is_instance_valid(firewall_barrier):
		return firewall_barrier.activate()
	return false

func deactivate_firewall() -> void:
	if firewall_barrier and is_instance_valid(firewall_barrier):
		firewall_barrier.deactivate_immediate()

func orient_towards_center(center: Vector3 = Vector3.ZERO) -> void:
	var dir = center - global_position
	dir.y = 0.0
	if dir.length_squared() > 0.001:
		dir = dir.normalized()
		# O ponto de coleta (DropZoneArea) e o Firewall estão em +Z local (Z = +3.2m).
		# Para que +Z aponte na direção do centro da placa-mãe, a rotação Y é atan2(dir.x, dir.z).
		rotation.y = atan2(dir.x, dir.z)

func _ready() -> void:
	orient_towards_center(Vector3.ZERO)
	_update_station_info()
	_setup_app_model()

	if not Engine.is_editor_hint():
		if drop_zone and not drop_zone.body_entered.is_connected(_on_body_entered_drop_zone):
			drop_zone.body_entered.connect(_on_body_entered_drop_zone)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

func _update_station_info() -> void:
	var info = null
	var kb = get_node_or_null("/root/KnowledgeBase")
	if kb and kb.SOFTWARE_STATIONS.has(software_id):
		info = kb.SOFTWARE_STATIONS[software_id]
	elif KnowledgeBase and KnowledgeBase.SOFTWARE_STATIONS.has(software_id):
		info = KnowledgeBase.SOFTWARE_STATIONS[software_id]

	if info:
		station_name = info["name"]
		station_color = info["color"]
		if label_name:
			label_name.text = info["icon"] + " " + station_name

	if beacon_mesh and beacon_mesh.material_override is StandardMaterial3D:
		var mat = beacon_mesh.material_override as StandardMaterial3D
		mat.albedo_color = Color(station_color.r, station_color.g, station_color.b, 0.35)
		mat.emission = station_color
		mat.emission_enabled = true

func _setup_app_model() -> void:
	var existing = get_node_or_null("AppModel")
	if existing:
		existing.name = "AppModel_Old"
		existing.queue_free()

	var target_name = app_model_name
	if target_name.is_empty() and SOFTWARE_TO_MODEL.has(software_id):
		target_name = SOFTWARE_TO_MODEL[software_id]

	if target_name.is_empty() or APPS_SCENE == null:
		return

	var glb_instance = APPS_SCENE.instantiate()
	var found_node: MeshInstance3D = null

	for child in glb_instance.get_children():
		if child.name == target_name or child.name.begins_with(target_name):
			if child is MeshInstance3D:
				found_node = child
				break
			for sub in child.get_children():
				if sub is MeshInstance3D:
					found_node = sub
					break
			if found_node:
				break

	if found_node and found_node.mesh:
		var app_mesh = MeshInstance3D.new()
		app_mesh.name = "AppModel"
		app_mesh.mesh = found_node.mesh

		if found_node.material_override:
			app_mesh.material_override = found_node.material_override
		for i in range(found_node.get_surface_override_material_count()):
			var mat = found_node.get_surface_override_material(i)
			if mat:
				app_mesh.set_surface_override_material(i, mat)

		# Os modelos em assets.glb medem 2x2x2 com base em Y=0.
		# A escala 2.0x resulta em uma estrutura monumental de 4m x 4m x 4m.
		app_mesh.scale = Vector3(2.0, 2.0, 2.0)
		app_mesh.position = Vector3.ZERO

		add_child(app_mesh)

		# Oculta o cubo placeholder enquanto preserva a colisão do StaticBody3D
		if building_mesh:
			building_mesh.visible = false

	glb_instance.queue_free()

func _on_body_entered_drop_zone(body: Node3D) -> void:
	if cooldown_timer > 0.0:
		return

	# Caso 1: O jogador entrou na drop zone carregando um cubo
	if body is PlayerController and body.carried_cube != null:
		var cube = body.carried_cube
		process_delivery_for_cube(cube, body)
		return

	# Caso 2: O próprio cubo foi arremessado e caiu na drop zone
	if body is FileCube and not body.is_carried:
		process_delivery_for_cube(body, null)

func process_delivery_for_cube(cube: FileCube, player: PlayerController) -> void:
	if is_firewall_active():
		flash_beacon(Color.RED)
		if player and player.carried_cube == cube:
			player.carried_cube = null
		cube.set_carried(false, null)
		var eject_dir = (cube.global_position - global_position).normalized() + Vector3.UP * 0.8
		cube.throw(eject_dir, 14.0)
		return

	cooldown_timer = 0.5
	var success = GameManager.register_delivery_attempt(cube.extension, software_id)

	# Se online, envia pacote de entrega ao servidor autoritativo
	if NetworkManager.is_connected_to_server:
		NetworkManager.send_packet({
			"type": "C2S_SUBMIT_DELIVERY",
			"softwareStationId": software_id,
			"cubeId": cube.name
		})

	if success:
		# Sucesso: feedback visual e remove o cubo entregue
		flash_beacon(Color.GREEN)
		if player and player.carried_cube == cube:
			player.carried_cube = null
		cube.queue_free()
	else:
		# Erro: feedback visual vermelho e ejeta o cubo com força
		flash_beacon(Color.RED)
		if player and player.carried_cube == cube:
			player.carried_cube = null

		cube.set_carried(false, null)
		var eject_dir = (cube.global_position - global_position).normalized() + Vector3.UP * 0.8
		cube.throw(eject_dir, 10.0)

func flash_beacon(target_color: Color) -> void:
	if beacon_mesh and beacon_mesh.material_override is StandardMaterial3D:
		var mat = beacon_mesh.material_override as StandardMaterial3D
		mat.albedo_color = Color(target_color.r, target_color.g, target_color.b, 0.7)
		mat.emission = target_color

		# Restaura a cor padrão após 0.4s
		await get_tree().create_timer(0.4).timeout
		if is_inside_tree() and mat:
			mat.albedo_color = Color(station_color.r, station_color.g, station_color.b, 0.35)
			mat.emission = station_color
