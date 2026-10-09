extends SceneTree
var erreurs := 0
func ok(c: bool, msg: String) -> void:
	print(("OK   " if c else "FAIL ") + msg)
	if not c: erreurs += 1
func touche(main) -> void:
	var e := InputEventAction.new()
	e.action = "action"
	e.pressed = true
	main._unhandled_input(e)
func _init() -> void:
	var main = load("res://scene/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.poser_drapeau("scenario_termine")
	main.charger_carte("labo_chen", Vector2i(7, 4))
	main.joueur.direction = Vector2i.UP
	touche(main)
	await create_timer(0.1).timeout
	ok(main.texte.text.contains("Alors, tu as choisi"), "avant le choix : rappel des balles")
	touche(main); touche(main)
	await create_timer(0.1).timeout
	ok(not main.boite.visible and not main.evenement_en_cours, "dialogue ferme")
	main.poser_drapeau("starter_choisi")
	touche(main)
	await create_timer(0.1).timeout
	ok(main.texte.text.contains("Prends soin"), "apres le choix : autre dialogue")
	print("=== ERREURS : ", erreurs)
	quit(1 if erreurs > 0 else 0)
