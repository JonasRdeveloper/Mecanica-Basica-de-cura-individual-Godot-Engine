extends CharacterBody3D

const VELOCIDADE = 5.0
const VELOCIDADE_PULO = 4.5

var npc_selecionado: CharacterBody3D = null

@onready var camera: Camera3D = $Camera3D
@onready var estado_espaco: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

# Variáveis para o sistema de Área de Cura AOE com posicionamento pelo mouse
@export var cena_area_cura_aoe: PackedScene           # Cena da área real (com cura) - arraste ÁreaCuraAOE.tscn
@export var cena_pre_visualizacao_aoe: PackedScene    # Cena da pré-visualização (apenas visual) - arraste PréVisualizaçãoCuraAOE.tscn

var modo_posicionamento_aoe: bool = false
var pre_visualizacao_instancia: Node3D = null

func _ready() -> void:
	pass  # Pode adicionar inicializações aqui se precisar

func _unhandled_input(event: InputEvent) -> void:
	# Seleção de NPC com clique esquerdo (fora do modo AOE)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if modo_posicionamento_aoe:
			_colocar_area_cura_aoe()
		else:
			_selecionar_npc()

	# Teclas de teste para dano e cura
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F:
				_causar_dano_teste()
			KEY_1:
				_curar_alvo()
			KEY_2:
				_alternar_modo_posicionamento_aoe()

func _process(_delta: float) -> void:
	# Atualiza a posição da pré-visualização enquanto o modo está ativo
	if modo_posicionamento_aoe and pre_visualizacao_instancia:
		var posicao_mouse = get_viewport().get_mouse_position()
		var origem_ray = camera.project_ray_origin(posicao_mouse)
		var fim_ray = origem_ray + camera.project_ray_normal(posicao_mouse) * 1000.0
		
		var consulta_ray = PhysicsRayQueryParameters3D.create(origem_ray, fim_ray)
		consulta_ray.collide_with_areas = false
		consulta_ray.collide_with_bodies = true
		consulta_ray.collision_mask = 1  # Ajuste para a layer do seu chão/terreno
		consulta_ray.exclude = [self]
		
		var resultado = estado_espaco.intersect_ray(consulta_ray)
		
		if resultado and resultado.has("position"):
			pre_visualizacao_instancia.global_position = resultado.position + Vector3(0, 0.1, 0)
			pre_visualizacao_instancia.visible = true
		else:
			pre_visualizacao_instancia.visible = false

func _physics_process(delta: float) -> void:
	# Gravidade
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Pulo
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = VELOCIDADE_PULO
	
	# Movimento WASD
	var input_dir = Input.get_vector("mover_para_esquerda", "mover_para_direita", "mover_para_frente", "mover_para_tras")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * VELOCIDADE
		velocity.z = direction.z * VELOCIDADE
	else:
		velocity.x = move_toward(velocity.x, 0, VELOCIDADE)
		velocity.z = move_toward(velocity.z, 0, VELOCIDADE)
	
	move_and_slide()

# ────────────────────────────────────────────────
# Funções de Seleção e Interação com NPCs
# ────────────────────────────────────────────────

func _selecionar_npc() -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 1000
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [self]
	
	var result = estado_espaco.intersect_ray(query)
	
	if result and result.collider is CharacterBody3D:
		npc_selecionado = result.collider
		print("NPC selecionado: ", npc_selecionado.name)
	else:
		npc_selecionado = null
		print("Nenhum NPC selecionado.")

func _get_health_component(target: CharacterBody3D) -> Health:
	if target == null:
		return null
	
	var comp = target.get_node_or_null("Health")
	if comp == null:
		for child in target.get_children():
			if child is Health:
				comp = child
				break
	return comp

func _causar_dano_teste() -> void:
	if npc_selecionado:
		var hp = _get_health_component(npc_selecionado)
		if hp:
			hp.receber_dano(25.0)
			print("Causou 25 de dano em ", npc_selecionado.name)
		else:
			print("NPC selecionado não tem componente de Saúde!")
	else:
		print("Nenhum NPC selecionado para causar dano.")

func _curar_alvo() -> void:
	if npc_selecionado:
		var hp = _get_health_component(npc_selecionado)
		if hp:
			hp.aplicar_cura(20.0)
			print("Curou 20 de ", npc_selecionado.name)
		else:
			print("NPC selecionado não tem componente de Saúde!")
	else:
		print("Nenhum NPC selecionado para curar.")

# ────────────────────────────────────────────────
# Sistema de Área de Cura AOE com Posicionamento
# ────────────────────────────────────────────────

func _alternar_modo_posicionamento_aoe() -> void:
	modo_posicionamento_aoe = not modo_posicionamento_aoe
	
	if modo_posicionamento_aoe:
		if not cena_pre_visualizacao_aoe:
			print("Cena de pré-visualização AOE não configurada no Inspetor!")
			modo_posicionamento_aoe = false
			return
		
		pre_visualizacao_instancia = cena_pre_visualizacao_aoe.instantiate()
		get_tree().current_scene.add_child(pre_visualizacao_instancia)
		pre_visualizacao_instancia.visible = true
		print("Modo de posicionamento AOE ativado! Mire com o mouse e clique esquerdo para colocar.")
	else:
		if pre_visualizacao_instancia:
			pre_visualizacao_instancia.queue_free()
			pre_visualizacao_instancia = null
		print("Modo de posicionamento AOE desativado.")

func _colocar_area_cura_aoe() -> void:
	if not cena_area_cura_aoe or not pre_visualizacao_instancia:
		print("Não é possível colocar a área AOE no momento.")
		return
	
	var instancia_area = cena_area_cura_aoe.instantiate()
	get_tree().current_scene.add_child(instancia_area)
	instancia_area.global_position = pre_visualizacao_instancia.global_position
	instancia_area.get_node("GPUParticles3D").set_emitting(true)
	
	print("Área de Cura AOE colocada em: ", instancia_area.global_position)
	
	# Sai automaticamente do modo após colocar
	_alternar_modo_posicionamento_aoe()
