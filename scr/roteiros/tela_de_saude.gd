extends Control

@export var componente_saude: Health

@onready var sarar: ProgressBar = $Sarar
@onready var barra_saude: ProgressBar = $Barra_Saude

func _ready() -> void:
	if componente_saude:
		# Conecta o sinal do componente à função de atualização visual
		componente_saude.saude_alterada.connect(_on_saude_alterada)
		
		# Inicialização visual
		barra_saude.max_value = componente_saude.saude_maxima
		sarar.max_value = componente_saude.saude_maxima
		_on_saude_alterada(componente_saude.saude, componente_saude.saude_maxima)

# Esta função só roda quando a vida realmente muda
func _on_saude_alterada(nova_saude: float, _max_saude: float) -> void:
	# 1. Atualiza a barra principal instantaneamente
	barra_saude.value = nova_saude
	
	# 2. Cria o efeito de "catch-up" (a barra de trás descendo suavemente ou subindo)
	if sarar.value != nova_saude:
		var interpolacao: Tween = create_tween()
		interpolacao.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		# Um pequeno delay para dar impacto visual antes de começar a mover a barra secundária
		interpolacao.tween_property(sarar, 'value', nova_saude, 0.5)
