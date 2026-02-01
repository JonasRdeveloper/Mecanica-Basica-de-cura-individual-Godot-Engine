extends Node3D

@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		$Campones/GameManager.saude -= 30 ## Não preciso mais deste comando!!!
