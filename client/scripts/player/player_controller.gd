extends CharacterBody3D
class_name PlayerController

## DIGITAL DELIVERY - Controlador do Jogador 3D
## Ref: Seções 1, 5, 7 e 11 do GDD.md
## Movimentação fluida, inércia leve, câmera orbital 3ª pessoa e sistema de carregar cubos
## Sistema completo de animação procedural via AnimationTree:
## - Idle <-> WalkStart <-> Walk
## - Blend Walk + Holding (filtro de ossos superiores)
## - HoldSwaying para Idle carregando objeto

@export var base_speed: float = 7.0
@export var acceleration: float = 28.0
@export var friction: float = 24.0
@export var mouse_sensitivity: float = 0.003

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var visual_model: Node3D = $VisualModel
@onready var carry_socket: Marker3D = $VisualModel/CarrySocket
@onready var pickup_detector: Area3D = $PickupDetector

var gravity: float = 20.0
var carried_cube: FileCube = null
var is_stunned: bool = false
var speed_multiplier: float = 1.0

# Sistema de Animação
var anim_player: AnimationPlayer = null
var anim_tree: AnimationTree = null
var _current_state: String = "idle"
var _walkstart_timer: float = 0.0
const WALKSTART_DURATION: float = 0.267

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_setup_animation_system()

func _setup_animation_system() -> void:
	# Localiza o AnimationPlayer dentro da hierarquia da personagem importada
	anim_player = visual_model.find_child("AnimationPlayer", true, false)
	if anim_player == null:
		push_warning("PlayerController: AnimationPlayer não encontrado em VisualModel/Gfx!")
		return

	# Configura modos de repetição das animações importadas
	if anim_player.has_animation("Idle"):
		anim_player.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
	if anim_player.has_animation("Walk"):
		anim_player.get_animation("Walk").loop_mode = Animation.LOOP_LINEAR
	if anim_player.has_animation("HoldSwaying"):
		anim_player.get_animation("HoldSwaying").loop_mode = Animation.LOOP_LINEAR
	if anim_player.has_animation("Holding"):
		anim_player.get_animation("Holding").loop_mode = Animation.LOOP_LINEAR
	if anim_player.has_animation("WalkStart"):
		anim_player.get_animation("WalkStart").loop_mode = Animation.LOOP_NONE

	# Constrói o AnimationTree dinamicamente
	anim_tree = AnimationTree.new()
	anim_tree.name = "PlayerAnimationTree"
	visual_model.add_child(anim_tree)
	anim_tree.anim_player = anim_tree.get_path_to(anim_player)

	var blend_tree = AnimationNodeBlendTree.new()

	# Nós de animação básica
	var anim_idle = AnimationNodeAnimation.new()
	anim_idle.animation = &"Idle"
	blend_tree.add_node("Idle", anim_idle)

	var anim_walkstart = AnimationNodeAnimation.new()
	anim_walkstart.animation = &"WalkStart"
	blend_tree.add_node("WalkStart", anim_walkstart)

	var anim_walk = AnimationNodeAnimation.new()
	anim_walk.animation = &"Walk"
	blend_tree.add_node("Walk", anim_walk)

	var anim_swaying = AnimationNodeAnimation.new()
	anim_swaying.animation = &"HoldSwaying"
	blend_tree.add_node("HoldSwaying", anim_swaying)

	var anim_holding = AnimationNodeAnimation.new()
	anim_holding.animation = &"Holding"
	blend_tree.add_node("Holding", anim_holding)

	var anim_walk_for_hold = AnimationNodeAnimation.new()
	anim_walk_for_hold.animation = &"Walk"
	blend_tree.add_node("WalkForHold", anim_walk_for_hold)

	# Blend2: Walk (pernas/base) + Holding (braços/tronco filtrados)
	var walk_hold = AnimationNodeBlend2.new()
	walk_hold.filter_enabled = true
	if anim_player.has_animation("Holding"):
		var holding_res = anim_player.get_animation("Holding")
		for i in range(holding_res.get_track_count()):
			var track_path = str(holding_res.track_get_path(i))
			# Filtra tronco, ombros, braços, mãos, pescoço e cabeça para a pose de segurar
			if "Spine" in track_path or "Shoulder" in track_path or "Arm" in track_path or "Hand" in track_path or "Neck" in track_path or "Head" in track_path:
				walk_hold.set_filter_path(NodePath(track_path), true)

	blend_tree.add_node("WalkHold", walk_hold)
	blend_tree.connect_node("WalkHold", 0, "WalkForHold")
	blend_tree.connect_node("WalkHold", 1, "Holding")

	# Transição principal entre os 5 estados do jogador
	var main_trans = AnimationNodeTransition.new()
	main_trans.input_count = 5
	main_trans.set_input_name(0, "idle")
	main_trans.set_input_name(1, "walkstart")
	main_trans.set_input_name(2, "walk")
	main_trans.set_input_name(3, "holdswaying")
	main_trans.set_input_name(4, "walkhold")
	main_trans.xfade_time = 0.18

	blend_tree.add_node("MainState", main_trans)
	blend_tree.connect_node("MainState", 0, "Idle")
	blend_tree.connect_node("MainState", 1, "WalkStart")
	blend_tree.connect_node("MainState", 2, "Walk")
	blend_tree.connect_node("MainState", 3, "HoldSwaying")
	blend_tree.connect_node("MainState", 4, "WalkHold")

	blend_tree.connect_node("output", 0, "MainState")

	anim_tree.tree_root = blend_tree
	anim_tree.active = true
	anim_tree.set("parameters/WalkHold/blend_amount", 1.0)
	anim_tree.set("parameters/MainState/transition_request", "idle")

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_in_game_terminal_open or GameManager.has_active_popup:
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		spring_arm.rotate_x(-event.relative.y * mouse_sensitivity)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(-60.0), deg_to_rad(45.0))

func _physics_process(delta: float) -> void:
	# Aplica gravidade
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Se o terminal in-game ou um popup abusivo estiver aberto, o jogador fica parado
	if GameManager.is_in_game_terminal_open or GameManager.has_active_popup:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)
		move_and_slide()
		_update_animations(delta, false)
		return

	# Ações de Pegar ou Soltar Cubo (E ou F)
	if Input.is_action_just_pressed("interact"):
		if carried_cube != null:
			drop_carried_cube()
		else:
			try_pickup_nearest_cube()

	if Input.is_action_just_pressed("drop_throw") and carried_cube != null:
		throw_carried_cube()

	# Movimentação Horizontal
	var is_moving = false
	if is_stunned:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)
	else:
		var input_dir = Vector2.ZERO
		if Input.is_action_pressed("move_forward"): input_dir.y -= 1.0
		if Input.is_action_pressed("move_backward"): input_dir.y += 1.0
		if Input.is_action_pressed("move_left"): input_dir.x -= 1.0
		if Input.is_action_pressed("move_right"): input_dir.x += 1.0
		input_dir = input_dir.normalized()

		# Direção relativa à orientação da câmera
		var cam_forward = -camera.global_transform.basis.z
		var cam_right = camera.global_transform.basis.x
		cam_forward.y = 0.0
		cam_right.y = 0.0
		cam_forward = cam_forward.normalized()
		cam_right = cam_right.normalized()

		var move_dir = (cam_forward * -input_dir.y + cam_right * input_dir.x).normalized()
		var target_speed = base_speed * speed_multiplier

		# Leve penalidade de peso ao carregar um arquivo
		if carried_cube != null:
			target_speed *= 0.92

		if move_dir != Vector3.ZERO:
			is_moving = true
			velocity.x = move_toward(velocity.x, move_dir.x * target_speed, acceleration * delta)
			velocity.z = move_toward(velocity.z, move_dir.z * target_speed, acceleration * delta)

			# Rotaciona modelo do personagem suavemente na direção do movimento
			var target_rot = atan2(-move_dir.x, -move_dir.z)
			visual_model.rotation.y = lerp_angle(visual_model.rotation.y, target_rot, 12.0 * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
			velocity.z = move_toward(velocity.z, 0.0, friction * delta)

	move_and_slide()

	# Atualiza a máquina de animação
	_update_animations(delta, is_moving)

	# Transmite posição para o servidor se online
	if NetworkManager.is_connected_to_server:
		NetworkManager.send_packet({
			"type": "C2S_PLAYER_INPUT",
			"position": { "x": global_position.x, "y": global_position.y, "z": global_position.z },
			"velocity": { "x": velocity.x, "y": velocity.y, "z": velocity.z },
			"yaw": visual_model.rotation.y
		})

func _update_animations(delta: float, is_moving: bool) -> void:
	if anim_tree == null or not anim_tree.active:
		return

	var is_holding = (carried_cube != null)
	var next_state = _current_state

	if is_holding:
		# Quando está segurando um cubo/app:
		_walkstart_timer = 0.0
		if is_moving:
			next_state = "walkhold"
		else:
			next_state = "holdswaying"
	else:
		# Quando as mãos estão livres:
		if is_moving:
			if _current_state == "idle" or _current_state == "holdswaying":
				# Início da corrida passa por walkstart
				next_state = "walkstart"
				_walkstart_timer = WALKSTART_DURATION
			elif _current_state == "walkstart":
				_walkstart_timer -= delta
				if _walkstart_timer <= 0.0:
					next_state = "walk"
			elif _current_state != "walk":
				next_state = "walk"
		else:
			_walkstart_timer = 0.0
			next_state = "idle"

	if next_state != _current_state:
		_current_state = next_state
		anim_tree.set("parameters/MainState/transition_request", _current_state)

func try_pickup_nearest_cube() -> void:
	var overlapping_areas = pickup_detector.get_overlapping_areas()
	var nearest_cube: FileCube = null
	var shortest_dist: float = 999.0

	for area in overlapping_areas:
		var parent = area.get_parent()
		if parent is FileCube and not parent.is_carried:
			var d = global_position.distance_to(parent.global_position)
			if d < shortest_dist:
				shortest_dist = d
				nearest_cube = parent

	if nearest_cube:
		carried_cube = nearest_cube
		carried_cube.set_carried(true, carry_socket)
		GameManager.carried_cube = carried_cube

		if NetworkManager.is_connected_to_server:
			NetworkManager.send_packet({
				"type": "C2S_GRAB_CUBE",
				"cubeId": carried_cube.name
			})

func drop_carried_cube() -> void:
	if carried_cube == null:
		return

	var throw_dir = -visual_model.global_transform.basis.z
	carried_cube.throw(throw_dir, 3.0)

	if NetworkManager.is_connected_to_server:
		NetworkManager.send_packet({
			"type": "C2S_DROP_CUBE",
			"cubeId": carried_cube.name
		})

	carried_cube = null
	GameManager.carried_cube = null

func throw_carried_cube() -> void:
	if carried_cube == null:
		return

	var throw_dir = -visual_model.global_transform.basis.z + Vector3.UP * 0.3
	carried_cube.throw(throw_dir, 10.0)

	if NetworkManager.is_connected_to_server:
		NetworkManager.send_packet({
			"type": "C2S_DROP_CUBE",
			"cubeId": carried_cube.name,
			"impulse": { "x": throw_dir.x * 10.0, "y": 4.0, "z": throw_dir.z * 10.0 }
		})

	carried_cube = null
	GameManager.carried_cube = null

func force_drop_from_hazard(knockback: Vector3) -> void:
	if carried_cube != null:
		carried_cube.throw(knockback.normalized(), knockback.length())
		carried_cube = null
		GameManager.carried_cube = null
	velocity += knockback
