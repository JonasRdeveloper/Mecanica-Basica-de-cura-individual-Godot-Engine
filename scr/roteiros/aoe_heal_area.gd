extends Area3D
class_name AoeHealArea

@export var cura_por_tick: float = 10.0
@export var duracao_total: float = 5.0
@export var intervalo_cura: float = 1.0
@export var duracao_surgimento: float = 0.8     # Duração do surgimento cinematográfico
@export var altura_maxima_cilindro: float = 6.0 # Altura final do pilar (escala Y = 1.0)

var alvos_dentro: Array[CharacterBody3D] = []

@export var mesh_visual: MeshInstance3D     # ← Esfera/base (arraste no Inspector)
@export var cilindro_luz: MeshInstance3D    # ← Pilar de luz (arraste no Inspector)

@onready var timer_cura: Timer = $TimerCura

func _ready() -> void:
	# Proteções contra valores inválidos
	duracao_surgimento = clamp(duracao_surgimento, 0.3, 1.5)
	
	# Configuração do timer de cura periódica
	timer_cura.wait_time = intervalo_cura
	timer_cura.timeout.connect(_aplicar_cura_tick)
	timer_cura.start()
	
	# Auto-destruição automática
	var timer_destruicao: Timer = Timer.new()
	add_child(timer_destruicao)
	timer_destruicao.wait_time = duracao_total
	timer_destruicao.one_shot = true
	timer_destruicao.timeout.connect(queue_free)
	timer_destruicao.start()
	
	# Inicia o surgimento cinematográfico
	_iniciar_surgimento_cinematografico()
	
	# Calcula quando começar o fade-out gradual (ex: últimos ~45% da duração)
	var tempo_ate_inicio_fade = duracao_total * 0.55
	var duracao_fade_out_real = duracao_total - tempo_ate_inicio_fade  # ~45% do tempo total
	
	var timer_fade_out: Timer = Timer.new()
	add_child(timer_fade_out)
	timer_fade_out.wait_time = tempo_ate_inicio_fade
	timer_fade_out.one_shot = true
	timer_fade_out.timeout.connect(_iniciar_fade_out_gradual.bind(duracao_fade_out_real))
	timer_fade_out.start()
	
	# Conexões de detecção de corpos
	body_entered.connect(_ao_entrar_corpo)
	body_exited.connect(_ao_sair_corpo)
	
	# Configuração de colisão (apenas detecção, sem física)
	collision_layer = 0
	collision_mask = 1  # Ajuste conforme sua layer de personagens

# ────────────────────────────────────────────────
# Detecção de entrada / saída
# ────────────────────────────────────────────────

func _ao_entrar_corpo(corpo: Node3D) -> void:
	if corpo is CharacterBody3D and corpo.is_in_group("feridos") and not alvos_dentro.has(corpo):
		alvos_dentro.append(corpo)
		print("Camponês entrou na área de cura: ", corpo.name)

func _ao_sair_corpo(corpo: Node3D) -> void:
	if corpo is CharacterBody3D and alvos_dentro.has(corpo):
		alvos_dentro.erase(corpo)
		print("Camponês saiu da área de cura: ", corpo.name)

# ────────────────────────────────────────────────
# Cura periódica
# ────────────────────────────────────────────────

func _aplicar_cura_tick() -> void:
	for alvo in alvos_dentro:
		var componente_saude: Health = _obter_componente_saude(alvo)
		if componente_saude:
			componente_saude.aplicar_cura(cura_por_tick)
			print("Curou ", cura_por_tick, " de ", alvo.name)
		else:
			print("Alvo sem componente de Saúde: ", alvo.name)
	
	timer_cura.start()

func _obter_componente_saude(alvo: CharacterBody3D) -> Health:
	if alvo == null:
		return null
	
	var comp = alvo.get_node_or_null("Health")
	if comp == null:
		for filho in alvo.get_children():
			if filho is Health:
				comp = filho
				break
	return comp

# ────────────────────────────────────────────────
# Surgimento cinematográfico
# ────────────────────────────────────────────────

func _iniciar_surgimento_cinematografico() -> void:
	if not cilindro_luz:
		print("CilindroLuz não encontrado na cena!")
		return
	
	# Estado inicial: invisível e sem altura
	cilindro_luz.scale = Vector3(1.0, 0.01, 1.0)
	
	var material_cilindro: ShaderMaterial = cilindro_luz.material_override
	if material_cilindro:
		material_cilindro.set_shader_parameter("fase_surgimento", 0.0)
		var cor_inicial = material_cilindro.get_shader_parameter("cor_primaria")
		cor_inicial.a = 0.0
		material_cilindro.set_shader_parameter("cor_primaria", cor_inicial)
	
	# Tween de surgimento
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	tween.parallel().tween_property(cilindro_luz, "scale:y", 1.0, duracao_surgimento)
	
	tween.parallel().tween_method(
		func(valor: float):
			if material_cilindro:
				var cor = material_cilindro.get_shader_parameter("cor_primaria")
				cor.a = valor
				material_cilindro.set_shader_parameter("cor_primaria", cor)
				material_cilindro.set_shader_parameter("fase_surgimento", valor),
		0.0, 1.0, duracao_surgimento
	)
	
	# Burst final no topo
	tween.tween_interval(duracao_surgimento * 0.6)
	tween.tween_property(cilindro_luz, "scale:x", 1.4, 0.15).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(cilindro_luz, "scale:z", 1.4, 0.15).set_trans(Tween.TRANS_SINE)
	tween.tween_property(cilindro_luz, "scale:x", 1.0, 0.25)
	tween.parallel().tween_property(cilindro_luz, "scale:z", 1.0, 0.25)

# ────────────────────────────────────────────────
# Fade-out gradual (começa antes do fim e é perceptível)
# ────────────────────────────────────────────────

func _iniciar_fade_out_gradual(duracao_fade_out: float) -> void:
	if duracao_fade_out <= 0.01:
		print("Fade-out ignorado: duração muito curta ou inválida")
		return

	var tween_out: Tween = create_tween()
	tween_out.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	var tween_tinha_algum_alvo = false
	
	# Esfera (base)
	if mesh_visual:
		if mesh_visual.material_override is ShaderMaterial:
			tween_tinha_algum_alvo = true
			var mat_esfera: ShaderMaterial = mesh_visual.material_override
			var cor_inicial_esf = mat_esfera.get_shader_parameter("cor_primaria") if mat_esfera.has_shader_parameter("cor_primaria") else Color(1,1,1,1)
			
			tween_out.parallel().tween_method(
				func(v: float):
					var c = cor_inicial_esf
					c.a = lerp(cor_inicial_esf.a, 0.0, v)
					mat_esfera.set_shader_parameter("cor_primaria", c)
					if mat_esfera.has_shader_parameter("intensidade_glow"):
						var glow = mat_esfera.get_shader_parameter("intensidade_glow")
						mat_esfera.set_shader_parameter("intensidade_glow", lerp(glow, 0.0, v)),
				0.0, 1.0, duracao_fade_out
			)
		else:
			print("Aviso: mesh_visual existe, mas material_override não é ShaderMaterial")
	else:
		print("Aviso: mesh_visual não foi atribuído (null)")

	# Cilindro (pilar)
	if cilindro_luz:
		if cilindro_luz.material_override is ShaderMaterial:
			tween_tinha_algum_alvo = true
			var mat_cil: ShaderMaterial = cilindro_luz.material_override
			var cor_inicial_cil = mat_cil.get_shader_parameter("cor_primaria") if mat_cil.has_shader_parameter("cor_primaria") else Color(1,1,1,1)
			var fase_inicial = mat_cil.get_shader_parameter("fase_surgimento") if mat_cil.has_shader_parameter("fase_surgimento") else 0.0
			
			tween_out.parallel().tween_method(
				func(v: float):
					var c = cor_inicial_cil
					c.a = lerp(cor_inicial_cil.a, 0.0, v)
					mat_cil.set_shader_parameter("cor_primaria", c)
					
					mat_cil.set_shader_parameter("fase_surgimento", lerp(fase_inicial, 0.0, v))
					if mat_cil.has_shader_parameter("intensidade_glow"):
						var glow = mat_cil.get_shader_parameter("intensidade_glow")
						mat_cil.set_shader_parameter("intensidade_glow", lerp(glow, 0.1, v)),
				0.0, 1.0, duracao_fade_out
			)
			
			# Contração vertical
			tween_out.parallel().tween_property(cilindro_luz, "scale:y", 0.05, duracao_fade_out)
			
			# Encolhimento radial suave
			tween_out.tween_property(cilindro_luz, "scale:x", 0.7, duracao_fade_out * 0.7)
			tween_out.parallel().tween_property(cilindro_luz, "scale:z", 0.7, duracao_fade_out * 0.7)
		else:
			print("Aviso: cilindro_luz existe, mas material_override não é ShaderMaterial")
	else:
		print("Aviso: cilindro_luz não foi atribuído (null)")

	# Se ninguém foi tweenado → tween vazio → erro
	if not tween_tinha_algum_alvo:
		print("AVISO CRÍTICO: Nenhum material válido encontrado para fade-out → tween vazio!")
		tween_out.kill()  # Mata o tween vazio para evitar o erro no console22
