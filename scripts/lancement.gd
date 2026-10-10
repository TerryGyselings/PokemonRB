extends Node
# Scene lancee au demarrage du jeu : charge la scene principale avec l'ecran titre.
# (les tests chargent directement scene/main.tscn, sans ecran titre)

func _ready() -> void:
	var m = load("res://scene/main.tscn").instantiate()
	m.avec_titre = true
	add_child(m)
