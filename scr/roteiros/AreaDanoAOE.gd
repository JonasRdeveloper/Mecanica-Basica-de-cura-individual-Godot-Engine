extends Area3D
class_name AreaDanoAOE

@export var dano_por_tick: float = 15.0
@export var duracao_total: float = 4.0
@export var intervalo_dano: float = 0.5  # Rápido para raios múltiplos
@export var duracao_surgimento: float = 0.6

var alvos_dentro: Array[CharacterBody3D] = []

@export var mesh_visual: MeshInstance3D  # Base roxa
@export var pilar_dano: MeshInstance3D   # Pilar roxo/escuro

@onready var timer_dano: Timer = $TimerDano

func _ready() -> void:
	duracao_surgimento = clamp(duracao_surgimento, 0.3, 1.0)
	
	timer_dano.wait_time = intervalo_dano
	timer_dano.timeout.connect(_aplicar_dano_tick)
	timer_dano.start()
	
	var timer_destruicao: Timer = Timer.new()
	add_child(timer_destruicao)
	timer_destruicao.wait_time = duracao_total
	timer_destruicao.one_shot = true
	timer_destruicao.timeout.connect(queue_free)
	timer_destruicao.start()
	
	_iniciar_surgimento_dano_cinematografico()
	
	# Fade-out gradual
	var tempo_fade_inicio = duracao_total * 0.5
	var duracao_fade_real = duracao_total * 0.5
	var timer_fade: Timer = Timer.new()
	add_child(timer_fade)
	timer_fade.wait_time = tempo_fade_inicio
	timer_fade.one_shot = true
	timer_fade.timeout.connect(_iniciar_fade_out_gradual.bind(duracao_fade_real))
	timer_fade.start()
	
	body_entered.connect(_ao_entrar_corpo)
	body_exited.connect(_ao_sair_corpo)
	collision_layer = 0
	collision_mask = 1

func _ao_entrar_corpo(corpo: Node3D) -> void:
	if corpo is CharacterBody3D and corpo.is_in_group("feridos") and not alvos_dentro.has(corpo):
		alvos_dentro.append(corpo)
		print("Alvo entrou na zona de raios: ", corpo.name)

func _ao_sair_corpo(corpo: Node3D) -> void:
	if corpo is CharacterBody3D and alvos_dentro.has(corpo):
		alvos_dentro.erase(corpo)

func _aplicar_dano_tick() -> void:
	if alvos_dentro.is_empty():
		timer_dano.start()
		return
	
	# Ordena alvos por % de vida restante (mais ferido primeiro = gameplay inteligente!)
	alvos_dentro.sort_custom(func(a, b):
		var health_a = _obter_componente_saude(a)
		var health_b = _obter_componente_saude(b)
		
		var pct_a = 1.0  # Default alto se não tiver health
		if health_a:
			pct_a = health_a.saude / health_a.saude_maxima
		
		var pct_b = 1.0
		if health_b:
			pct_b = health_b.saude / health_b.saude_maxima
		
		return pct_a < pct_b
	)
	
	for i in range(min(3, alvos_dentro.size())):  # Máx 3 raios por tick
		var alvo = alvos_dentro[i]
		var health = _obter_componente_saude(alvo)
		if health:
			health.receber_dano(dano_por_tick)
			_criar_raio_visual(alvo)
			print("Raio atingiu ", alvo.name, " (", dano_por_tick, " dano)")
	
	timer_dano.start()

func _criar_raio_visual(alvo: CharacterBody3D) -> void:
	var raio = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.height = 30.0                  # Altura total do raio
	cylinder.radial_segments = 12
	cylinder.cap_bottom = false
	raio.mesh = cylinder
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.3, 1.0, 0.0)  # Inicia invisível
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.3, 1.0)
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	raio.material_override = mat
	
	# 1. ADICIONA PRIMEIRO à árvore (essencial!)
	add_child(raio)
	
	# 2. Agora sim, define posição e orientação com segurança
	var altura_raio = cylinder.height / 2.0
	raio.global_position = alvo.global_position + Vector3(0, altura_raio, 0)
	
	# Não precisa de look_at() — cilindro já é vertical por padrão
	# (se quiser inclinação leve, use rotation em vez de look_at)
	
	# Tween juice
	var tween = create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(mat, "albedo_color:a", 0.85, 0.08)
	tween.tween_property(mat, "emission_energy_multiplier", 6.0, 0.08).from(4.0)
	
	tween.tween_property(raio, "scale:x", 1.5, 0.12).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(raio, "scale:z", 1.5, 0.12).set_trans(Tween.TRANS_SINE)
	
	tween.tween_interval(0.18)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.28)
	tween.parallel().tween_property(mat, "emission_energy_multiplier", 0.0, 0.28)
	tween.parallel().tween_property(raio, "scale:x", 0.3, 0.28)
	tween.parallel().tween_property(raio, "scale:z", 0.3, 0.28)
	
	tween.tween_callback(raio.queue_free)

func _obter_componente_saude(alvo: CharacterBody3D) -> Health:
	if alvo == null: return null
	var comp = alvo.get_node_or_null("Health")
	if comp == null:
		for child in alvo.get_children():
			if child is Health: return child
	return comp

# ────────────────────────────────────────────────
# Surgimento cinematográfico (adaptado da cura)
# ────────────────────────────────────────────────

func _iniciar_surgimento_dano_cinematografico() -> void:
	if not pilar_dano:
		print("PilarDano não encontrado na cena!")
		return
	
	# Inicial: invisível e sem altura
	pilar_dano.scale = Vector3(1.0, 0.01, 1.0)
	
	var material_pilar: ShaderMaterial = pilar_dano.material_override
	if material_pilar:
		material_pilar.set_shader_parameter("fase_surgimento", 0.0)
		var cor_inicial = material_pilar.get_shader_parameter("cor_primaria")
		cor_inicial.a = 0.0
		material_pilar.set_shader_parameter("cor_primaria", cor_inicial)
	
	# Tween de surgimento
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	tween.parallel().tween_property(pilar_dano, "scale:y", 1.0, duracao_surgimento)
	
	tween.parallel().tween_method(
		func(valor: float):
			if material_pilar:
				var cor = material_pilar.get_shader_parameter("cor_primaria")
				cor.a = valor
				material_pilar.set_shader_parameter("cor_primaria", cor)
				material_pilar.set_shader_parameter("fase_surgimento", valor),
		0.0, 1.0, duracao_surgimento
	)
	
	# Burst final
	tween.tween_interval(duracao_surgimento * 0.6)
	tween.tween_property(pilar_dano, "scale:x", 1.4, 0.15).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(pilar_dano, "scale:z", 1.4, 0.15).set_trans(Tween.TRANS_SINE)
	tween.tween_property(pilar_dano, "scale:x", 1.0, 0.25)
	tween.parallel().tween_property(pilar_dano, "scale:z", 1.0, 0.25)

# ────────────────────────────────────────────────
# Fade-out gradual (adaptado da cura)
# ────────────────────────────────────────────────

func _iniciar_fade_out_gradual(duracao_fade_out: float) -> void:
	if duracao_fade_out <= 0.01:
		print("Fade-out ignorado: duração inválida ou muito curta")
		return

	var tween_out: Tween = null  # Só criamos se precisar
	var algo_foi_animado = false

	# Esfera (base)
	if mesh_visual and mesh_visual.material_override is ShaderMaterial:
		if tween_out == null:
			tween_out = create_tween()
			tween_out.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
		algo_foi_animado = true
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
		if not mesh_visual:
			print("Aviso fade-out: mesh_visual não foi atribuído (null)")
		elif not mesh_visual.material_override:
			print("Aviso fade-out: mesh_visual sem material_override")
		elif not mesh_visual.material_override is ShaderMaterial:
			print("Aviso fade-out: material da mesh_visual não é ShaderMaterial")

	# Pilar de dano
	if pilar_dano and pilar_dano.material_override is ShaderMaterial:
		if tween_out == null:
			tween_out = create_tween()
			tween_out.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
		algo_foi_animado = true
		var mat_pilar: ShaderMaterial = pilar_dano.material_override
		var cor_inicial_pilar = mat_pilar.get_shader_parameter("cor_primaria") if mat_pilar.has_shader_parameter("cor_primaria") else Color(1,1,1,1)
		var fase_inicial = mat_pilar.get_shader_parameter("fase_surgimento") if mat_pilar.has_shader_parameter("fase_surgimento") else 0.0
		
		tween_out.parallel().tween_method(
			func(v: float):
				var c = cor_inicial_pilar
				c.a = lerp(cor_inicial_pilar.a, 0.0, v)
				mat_pilar.set_shader_parameter("cor_primaria", c)
				mat_pilar.set_shader_parameter("fase_surgimento", lerp(fase_inicial, 0.0, v))
				if mat_pilar.has_shader_parameter("intensidade_glow"):
					var glow = mat_pilar.get_shader_parameter("intensidade_glow")
					mat_pilar.set_shader_parameter("intensidade_glow", lerp(glow, 0.1, v)),
			0.0, 1.0, duracao_fade_out
		)
		
		# Contração vertical
		tween_out.parallel().tween_property(pilar_dano, "scale:y", 0.05, duracao_fade_out)
		
		# Encolhimento radial
		tween_out.tween_property(pilar_dano, "scale:x", 0.7, duracao_fade_out * 0.7)
		tween_out.parallel().tween_property(pilar_dano, "scale:z", 0.7, duracao_fade_out * 0.7)
	else:
		if not pilar_dano:
			print("Aviso fade-out: pilar_dano não foi atribuído (null)")
		elif not pilar_dano.material_override:
			print("Aviso fade-out: pilar_dano sem material_override")
		elif not pilar_dano.material_override is ShaderMaterial:
			print("Aviso fade-out: material do pilar_dano não é ShaderMaterial")

	# Se nada foi animado → não criamos tween vazio
	if tween_out != null and not algo_foi_animado:
		print("Aviso: Tween de fade-out criado mas sem animações → matando tween vazio")
		tween_out.kill()
	elif algo_foi_animado:
		print("Fade-out gradual iniciado com sucesso (duração: ", duracao_fade_out, "s)")
