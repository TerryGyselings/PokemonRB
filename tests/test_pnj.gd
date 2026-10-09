extends SceneTree
# PNJ : solides, se tournent vers le joueur, dialogue, drapeaux (visible_si, cache_si, pose)
var erreurs := 0
func ok(c: bool, msg: String) -> void:
	print(("OK   " if c else "FAIL ") + msg)
	if not c: erreurs += 1
func marche(j, d: Vector2i, n := 1) -> void:
	for i in n:
		j.deplacer(d)
		await create_timer(0.3).timeout
func appuyer(main) -> void:
	var e := InputEventAction.new()
	e.action = "action"
	e.pressed = true
	main._unhandled_input(e)
func _init() -> void:
	var main = load("res://scene/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.carte.dossier = "res://tests/cartes"
	main.carte.fichier_monde = ""
	main.charger_carte("pnj")
	var j = main.joueur
	ok(main.pnj_a(Vector2i(3, 2)) != null, "PNJ A present")
	ok(main.pnj_a(Vector2i(5, 1)) == null, "PNJ B cache (visible_si pas rempli)")
	ok(main.pnj_a(Vector2i(1, 3)) != null, "PNJ C present")
	# solide : le joueur (1,2) va vers la droite jusqu'a A
	await marche(j, Vector2i.RIGHT, 3)
	ok(j.case == Vector2i(2, 2), "PNJ solide : le joueur s'arrete en %s" % j.case)
	# dialogue : A se tourne vers le joueur (a gauche)
	appuyer(main)
	ok(main.boite.visible and main.texte.text == "Salut.", "dialogue page 1")
	ok(main.pnj_a(Vector2i(3, 2)).direction == Vector2i.LEFT, "le PNJ se tourne vers le joueur")
	appuyer(main)
	ok(main.texte.text == "Deuxieme page.", "dialogue page 2")
	appuyer(main)
	ok(not main.boite.visible, "dialogue ferme")
	ok(main.a_drapeau("a_parle"), "drapeau 'pose' pose apres le dialogue")
	ok(main.pnj_a(Vector2i(1, 3)) == null, "cache_si : C a disparu")
	# visible_si
	main.poser_drapeau("b_apparait")
	ok(main.pnj_a(Vector2i(5, 1)) != null, "visible_si : B apparait")
	# pas d'apparition sur le joueur
	main.carte.pnj_donnees[1]["x"] = 2
	main.carte.pnj_donnees[1]["y"] = 2
	main._creer_pnj()
	ok(main.pnj_a(Vector2i(2, 2)) == null, "un PNJ n'apparait pas sur le joueur")
	print("=== ERREURS : %d" % erreurs)
	quit()
