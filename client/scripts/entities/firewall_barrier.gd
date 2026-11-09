extends Node3D
class_name FirewallBarrier

## DIGITAL DELIVERY - Barreira de Firewall nos Aplicativos
## Bloqueia o acesso à estação de software.
## Transição: Carrega shader da base ao topo durante 4s total;
## Ao finalizar a materialização, conta a duração de 6s bloqueando completamente.

signal firewall_started_buildup()
signal firewall_fully_active()
signal firewall_deactivated()

enum State {
	INACTIVE,
	BUILDING,
	ACTIVE,
	DISSOLVING
}

const FIREWALL_SCENE = preload("res://models/firewall/firewall.glb")
const FIREWALL_SHADER = preload("res://shaders/firewall_wipe.gdshader")
const TEXTURE_ALBEDO = preload("res://models/firewall/firewall_firewall-texture.png")
const TEXTURE_EMISSION = preload("res://models/firewall/firewall_firewall-emission.png")
const TEXTURE_NORMAL = preload("res://models/firewall/firewall_firewall-normal.png")

const BUILDUP_TIME: float = 4.0   # 4s de materialização bottom-to-top
const ACTIVE_DURATION: float = 6.0 # 6s de duração ativa após carregamento
const DISSOLVE_TIME: float = 0.8  # 0.8s para dissolver ao desativar

@onready var firewall_mesh: MeshInstance3D = $FirewallMesh
@onready var collision_shape: CollisionShape3D = $StaticBody3D/CollisionShape3D
@onready var repel_area: Area3D = $RepelArea
@onready var firewall_light: OmniLight3D = $FirewallLight

var state: State = State.INACTIVE
var buildup_timer: float = 0.0
var active_timer: float = 0.0
var dissolve_timer: float = 0.0
var shader_mat: ShaderMaterial

func _ready() -> void:
	_setup_mesh_and_shader()
	deactivate_immediate()

	if repel_area:
		repel_area.body_entered.connect(_on_repel_body_entered)

func _setup_mesh_and_shader() -> void:
	if firewall_mesh == null:
		return

	# Extrai malha autêntica do firewall.glb se ainda não configurada
	if firewall_mesh.mesh == null and FIREWALL_SCENE:
		var glb_inst = FIREWALL_SCENE.instantiate()
		for child in glb_inst.get_children():
			if child is MeshInstance3D and child.mesh:
				firewall_mesh.mesh = child.mesh
				break
		glb_inst.queue_free()

	# Configura o ShaderMaterial com a transição vertical
	shader_mat = ShaderMaterial.new()
	shader_mat.shader = FIREWALL_SHADER
	shader_mat.set_shader_parameter("albedo_texture", TEXTURE_ALBEDO)
	shader_mat.set_shader_parameter("emission_texture", TEXTURE_EMISSION)
	shader_mat.set_shader_parameter("normal_texture", TEXTURE_NORMAL)
	shader_mat.set_shader_parameter("wipe_progress", 0.0)
	shader_mat.set_shader_parameter("alpha_mult", 1.0)
	shader_mat.set_shader_parameter("firewall_color", Color("#FF5500"))
	firewall_mesh.material_override = shader_mat

func _process(delta: float) -> void:
	match state:
		State.BUILDING:
			buildup_timer += delta
			var progress = clamp(buildup_timer / BUILDUP_TIME, 0.0, 1.0)
			if shader_mat:
				shader_mat.set_shader_parameter("wipe_progress", progress)
			if firewall_light:
				firewall_light.light_energy = progress * 2.8

			# Ao finalizar os 4s de carregamento geral, inicia a contagem de 6s
			if buildup_timer >= BUILDUP_TIME:
				state = State.ACTIVE
				active_timer = ACTIVE_DURATION
				if shader_mat:
					shader_mat.set_shader_parameter("wipe_progress", 1.0)
				firewall_fully_active.emit()

		State.ACTIVE:
			active_timer -= delta
			if firewall_light:
				var pulse = sin(Time.get_ticks_msec() * 0.008) * 0.4 + 2.4
				firewall_light.light_energy = pulse

			# Tempo esgotado (6 segundos): inicia dissolução suave
			if active_timer <= 0.0:
				state = State.DISSOLVING
				dissolve_timer = DISSOLVE_TIME

		State.DISSOLVING:
			dissolve_timer -= delta
			var alpha = clamp(dissolve_timer / DISSOLVE_TIME, 0.0, 1.0)
			if shader_mat:
				shader_mat.set_shader_parameter("alpha_mult", alpha)
			if firewall_light:
				firewall_light.light_energy = alpha * 2.0

			if dissolve_timer <= 0.0:
				deactivate_immediate()
				firewall_deactivated.emit()

func activate() -> bool:
	if state != State.INACTIVE:
		return false

	state = State.BUILDING
	buildup_timer = 0.0
	active_timer = 0.0
	visible = true

	if collision_shape:
		collision_shape.disabled = false
	if shader_mat:
		shader_mat.set_shader_parameter("wipe_progress", 0.0)
		shader_mat.set_shader_parameter("alpha_mult", 1.0)
	if firewall_light:
		firewall_light.visible = true
		firewall_light.light_energy = 0.2

	firewall_started_buildup.emit()
	return true

func deactivate_immediate() -> void:
	state = State.INACTIVE
	visible = false
	buildup_timer = 0.0
	active_timer = 0.0
	dissolve_timer = 0.0

	if collision_shape:
		collision_shape.disabled = true
	if firewall_light:
		firewall_light.visible = false
	if shader_mat:
		shader_mat.set_shader_parameter("wipe_progress", 0.0)
		shader_mat.set_shader_parameter("alpha_mult", 0.0)

func is_blocking() -> bool:
	return state == State.BUILDING or state == State.ACTIVE

func _on_repel_body_entered(body: Node3D) -> void:
	if not is_blocking():
		return

	# Repele jogadores que colidirem com o firewall
	if body is PlayerController:
		var push_dir = (body.global_position - global_position)
		push_dir.y = 0.3
		push_dir = push_dir.normalized()
		body.velocity = push_dir * 12.0

	# Repele cubos de arquivos arremessados contra a redoma
	elif body is FileCube:
		var push_dir = (body.global_position - global_position)
		push_dir.y = 0.6
		body.throw(push_dir.normalized(), 12.0)
