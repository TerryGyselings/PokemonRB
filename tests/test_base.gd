extends SceneTree
var erreurs := 0
func ok(c: bool, msg: String) -> void:
	print(("OK   " if c else "FAIL ") + msg)
	if not c: erreurs += 1
func marcher(j, d: Vector2i) -> void:
	j.deplacer(d)
	await create_timer(0.3).timeout
func _init() -> void:
	var main = load("res://scene/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.carte.dossier = "res://tests/cartes"
	main.carte.fichier_monde = ""
	main.charger_carte("bourg_palette")
	var j = main.joueur
	ok(main.carte.id == "bourg_palette", "carte de depart chargee")
	ok(j.case == Vector2i(10, 10), "joueur au depart")
	ok(main.carte.largeur == 20 and main.carte.hauteur == 18, "taille 20x18")
	ok(main.carte.solide(Vector2i(0, 0)), "arbre solide")
	ok(not main.carte.solide(Vector2i(10, 10)), "chemin libre")
	ok(main.carte.solide(Vector2i(-1, 5)), "hors carte = solide")
	# collision : aller vers le haut jusqu'au mur
	for i in 3: await marcher(j, Vector2i.LEFT)
	ok(j.case == Vector2i(7, 10), "3 pas a gauche")
	# vers les portes : (6,9) chemin, (6,6) porte
	await marcher(j, Vector2i.LEFT)   # (6,10) herbe
	for i in 3: await marcher(j, Vector2i.UP)  # (6,7)
	ok(j.case == Vector2i(6, 7), "devant la porte : %s" % j.case)
	await marcher(j, Vector2i.UP)   # porte (6,6)
	await create_timer(0.8).timeout
	ok(main.carte.id == "maison_joueur", "porte -> maison (%s)" % main.carte.id)
	ok(j.case == Vector2i(3, 6), "arrivee dans la maison %s" % j.case)
	# table: interaction (2,2)
	main.carte.interaction(Vector2i(2, 2))
	ok(not main.carte.interaction(Vector2i(2, 2)).is_empty(), "interaction table")
	ok(main.carte.solide(Vector2i(2, 2)), "table solide")
	# sortie
	await marcher(j, Vector2i.DOWN)
	await create_timer(0.8).timeout
	ok(main.carte.id == "bourg_palette" and j.case == Vector2i(6, 7), "retour au bourg %s" % j.case)
	# dialogue sur le panneau (8,7) : se placer en (7,7) face a droite
	await marcher(j, Vector2i.RIGHT)
	ok(j.case == Vector2i(7, 7), "a cote du panneau")
	await marcher(j, Vector2i.RIGHT)   # bloque par le panneau
	ok(j.case == Vector2i(7, 7) and j.direction == Vector2i.RIGHT, "panneau solide")
	var e := InputEventAction.new(); e.action = "action"; e.pressed = true
	main._unhandled_input(e)
	ok(main.boite.visible and main.texte.text == "BOURG PALETTE", "dialogue page 1")
	main._unhandled_input(e)
	ok(main.texte.text.begins_with("Un monde"), "dialogue page 2")
	main._unhandled_input(e)
	ok(not main.boite.visible and not j.bloque, "dialogue ferme")
	print("=== ERREURS : %d" % erreurs)
	quit()
