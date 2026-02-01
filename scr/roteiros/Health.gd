extends Node
class_name Health

# Criamos um sinal para avisar quando a saúde mudar
signal saude_alterada(nova_saude, max_saude)

@export var saude_maxima: float = 100.0
@onready var saude: float = saude_maxima

func _ready() -> void:
	# Emite o sinal inicial para configurar a barra na largada
	saude_alterada.emit(saude, saude_maxima)

func aplicar_cura(cura: float) -> void:
	var saude_anterior = saude
	saude = clampf(saude + cura, 0, saude_maxima)
	
	# Só emitimos o sinal e atualizamos se houver mudança real
	if saude != saude_anterior:
		saude_alterada.emit(saude, saude_maxima)

func receber_dano(dano: float) -> void:
	var saude_anterior = saude
	saude = clampf(saude - dano, 0, saude_maxima)
	
	if saude != saude_anterior:
		saude_alterada.emit(saude, saude_maxima)
		print("Dano recebido! Vida atual: ", saude)
