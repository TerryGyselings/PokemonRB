extends SceneTree
# Variables dans les textes des JSON : ${nom_joueur}, ${argent}
var erreurs := 0
func ok(c: bool, msg: String) -> void:
	print(("OK   " if c else "FAIL ") + msg)
	if not c: erreurs += 1
func _init() -> void:
	var main = load("res://scene/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.nom_joueur = "ASH"
	main.argent = 450
	main.dire(["${nom_joueur} joue à la Switch 2!", "... Bon! Faut y aller!", "${nom_joueur} a ${argent} P."])
	ok(main.texte.text == "ASH joue à la Switch 2!", "nom du joueur dans un dialogue : %s" % main.texte.text)
	main._avancer_dialogue()
	main._avancer_dialogue()
	ok(main.texte.text == "ASH a 450 P.", "plusieurs variables : %s" % main.texte.text)
	# la vraie interaction de la chambre (lit sur la carte reelle)
	main.boite.visible = false
	main.joueur.bloque = false
	main.nom_joueur = "TERRY"
	main.charger_carte("etage_joueur", Vector2i(5, 4))
	main.joueur.direction = Vector2i.RIGHT
	var e := InputEventAction.new()
	e.action = "action"
	e.pressed = true
	main._unhandled_input(e)
	ok(main.boite.visible and main.texte.text.begins_with("TERRY joue"), "interaction de la chambre : %s" % main.texte.text)
	print("=== ERREURS : ", erreurs)
	quit(1 if erreurs > 0 else 0)
