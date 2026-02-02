extends Area3D
class_name AoeHealArea

@export var cura_por_tick: float = 10.0      # Cura aplicada a cada intervalo
@export var duracao_total: float = 5.0       # Tempo total que a área permanece ativa (em segundos)
@export var intervalo_cura: float = 1.0      # Tempo entre cada aplicação de cura

var alvos_dentro: Array[CharacterBody3D] = []  # Lista de camponeses dentro da área

@onready var timer_cura: Timer = $TimerCura
@onready var mesh_visual: MeshInstance3D = $MeshInstance3D  # Opcional, para fade out

func _ready() -> void:
	# Configura o timer de cura com base nos valores exportados
	timer_cura.wait_time = intervalo_cura
	timer_cura.timeout.connect(_aplicar_cura_tick)
	timer_cura.start()
	
	# Timer para destruir automaticamente a área após a duração total
	var timer_destruicao: Timer = Timer.new()
	add_child(timer_destruicao)
	timer_destruicao.wait_time = duracao_total
	timer_destruicao.one_shot = true
	timer_destruicao.timeout.connect(queue_free)
	timer_destruicao.start()
	
	# Garante que há um material override (configure no editor para transparência Alpha)
	if not mesh_visual.material_override:
		var material = StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA  # Ativa transparência
		material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)  # Exemplo: azul semi-transparente
		mesh_visual.material_override = material
	
	# Tween no alpha da cor albedo do material
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	tween.tween_property(mesh_visual.material_override, "albedo_color:a", 0.0, duracao_total)
	
	# Conecta detecção de entrada e saída
	body_entered.connect(_ao_entrar_corpo)
	body_exited.connect(_ao_sair_corpo)
	
	# Configurações de colisão: só detecta, não colide fisicamente
	collision_layer = 0          # Não colide com nada
	collision_mask = 1           # Detecta layer 1 (ajuste conforme suas camadas de colisão)

func _ao_entrar_corpo(corpo: Node3D) -> void:
	if corpo is CharacterBody3D and corpo.is_in_group("feridos") and not alvos_dentro.has(corpo):
		alvos_dentro.append(corpo)
		print("Camponês entrou na área de cura: ", corpo.name)

func _ao_sair_corpo(corpo: Node3D) -> void:
	if corpo is CharacterBody3D and alvos_dentro.has(corpo):
		alvos_dentro.erase(corpo)
		print("Camponês saiu da área de cura: ", corpo.name)

func _aplicar_cura_tick() -> void:
	for alvo in alvos_dentro:
		var componente_saude: Health = _obter_componente_saude(alvo)
		if componente_saude:
			componente_saude.aplicar_cura(cura_por_tick)
			print("Curou ", cura_por_tick, " de ", alvo.name)
		else:
			print("Alvo sem componente de Saúde: ", alvo.name)
	
	# Reinicia o timer para o próximo tick
	timer_cura.start()

# Função auxiliar para encontrar o componente de saúde com segurança
func _obter_componente_saude(alvo: CharacterBody3D) -> Health:
	if alvo == null: return null
	
	var comp = alvo.get_node_or_null("Health")
	if comp == null:
		for filho in alvo.get_children():
			if filho is Health:
				comp = filho
				break
	return comp
