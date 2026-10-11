extends SceneTree
# L'escalier est solide sauf si on arrive de la gauche ("depuis": "gauche")
var erreurs := 0
func ok(c: bool, msg: String) -> void:
	print(("OK   " if c else "FAIL ") + msg)
	if not c: erreurs += 1
func marche(j, d: Vector2i, n := 1) -> void:
	for i in n:
		j.deplacer(d)
		await create_timer(0.3).timeout
func _init() -> void:
	load("res://scripts/pokemon.gd").deterministe = true
	var main = load("res://scene/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.carte.dossier = "res://tests/cartes"
	main.carte.fichier_monde = ""
	main.charger_carte("rdc")
	var j = main.joueur
	# escalier en (4,1) : depuis le bas -> rien
	j.placer(Vector2i(4, 2))
	await marche(j, Vector2i.UP)
	ok(main.carte.id == "rdc" and j.case == Vector2i(4, 2), "depuis le bas : escalier solide, le joueur reste en bas (%s %s)" % [main.carte.id, j.case])
	# depuis la droite -> rien
	j.placer(Vector2i(5, 1))
	await marche(j, Vector2i.LEFT)
	await create_timer(0.6).timeout
	ok(main.carte.id == "rdc" and j.case == Vector2i(5, 1), "depuis la droite : escalier solide (%s)" % j.case)
	# depuis la gauche -> etage
	j.placer(Vector2i(3, 1))
	await marche(j, Vector2i.RIGHT)
	await create_timer(0.8).timeout
	ok(main.carte.id == "etage" and j.case == Vector2i(3, 1), "depuis la gauche : etage, arrivee (%s %s)" % [main.carte.id, j.case])
	# retour : se remettre a gauche de l'escalier de l'etage
	await marche(j, Vector2i.RIGHT)
	await create_timer(0.8).timeout
	ok(main.carte.id == "rdc" and j.case == Vector2i(3, 1), "retour au rez-de-chaussee (%s %s)" % [main.carte.id, j.case])
	print("=== ERREURS : %d" % erreurs)
	quit()
