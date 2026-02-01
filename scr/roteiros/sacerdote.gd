extends CharacterBody3D

const SPEED: float = 5.0
const JUMP_VELOCITY: float = 4.5
var npc_selecionado: Node3D = null

@onready var camera = $Camera3D
@onready var space_state = get_world_3d().direct_space_state

func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_selecionar_npc()
	
	# --- NOVO: Tecla F para causar Dano (Teste) ---
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		_causar_dano_teste()
		
	# Exemplo: Botão Direito para Curar (se já não tiver implementado)
	if event is InputEventKey and event.pressed and event.keycode == KEY_1:
		_curar_alvo()

func _selecionar_npc():
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 1000
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	if result:
		npc_selecionado = result.collider
		print("NPC selecionado: ", npc_selecionado.name)

# --- FUNÇÕES DE INTERAÇÃO COM A VIDA ---

# Função auxiliar para pegar o componente de vida com segurança
func _get_health_component(target: Node) -> Health:
	if target == null: return null
	
	# Tenta pegar pelo nome "Health"
	var comp = target.get_node_or_null("Health")
	
	# Se não achar, procura nos filhos pelo TIPO da classe
	if comp == null:
		for child in target.get_children():
			if child is Health:
				comp = child
				break
	return comp

func _causar_dano_teste():
	if npc_selecionado:
		var hp = _get_health_component(npc_selecionado)
		if hp:
			hp.receber_dano(25.0) # Tira 25 de vida
			print("Causou 25 de dano em ", npc_selecionado.name)
		else:
			print("NPC selecionado não tem componente de Vida (Health)!")
	else:
		print("Nenhum NPC selecionado para causar dano.")

func _curar_alvo():
	if npc_selecionado:
		var hp = _get_health_component(npc_selecionado)
		if hp:
			hp.aplicar_cura(20.0) # Cura 20 de vida
			print("Curou ", npc_selecionado.name)

# ... (Mantenha o _physics_process igual estava)
func _physics_process(delta):
	if not is_on_floor():
		velocity += get_gravity() * delta
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	var input_dir = Input.get_vector("mover_para_esquerda", "mover_para_direita", "mover_para_frente", "mover_para_tras")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	move_and_slide()
