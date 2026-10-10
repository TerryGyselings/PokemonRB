extends SceneTree
# Clic dans le monde : parler a un PNJ, lire une pancarte, examiner un objet (a cote, ou en marchant jusqu'a eux)
var erreurs := 0
func ok(c: bool, msg: String) -> void:
	print(("OK   " if c else "FAIL ") + msg)
	if not c: erreurs += 1
func ecran(main, c: Vector2i) -> Vector2:
	return main.get_canvas_transform() * (Vector2(c * 16) + Vector2(8, 8))
func clic(main, c: Vector2i, bouton := MOUSE_BUTTON_LEFT) -> void:
	var e := InputEventMouseButton.new()
	e.position = ecran(main, c)
	e.button_index = bouton
	e.pressed = true
	main._input(e)
	await process_frame
func ferme(main) -> void:
	while main.boite.visible:
		var e := InputEventAction.new()
		e.action = "action"
		e.pressed = true
		main._unhandled_input(e)
		await process_frame
func _init() -> void:
	var main = load("res://scene/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.carte.dossier = "res://tests/cartes"
	main.carte.fichier_monde = ""
	main.charger_carte("pnj")
	var j = main.joueur
	# une pancarte et un objet, ajoutes en memoire sur la carte de test
	main.carte._interactions[Vector2i(5, 3)] = {"x": 5, "y": 3, "texte": ["ROUTE 1"]}
	main.carte.pnj_donnees.append({"id": "obj", "nom": "Objet", "x": 4, "y": 1, "direction": "bas", "couleur": "#ffcc00", "objet": true, "texte": ["Une POKe BALL."]})
	main._creer_pnj()
	for i in 3: await process_frame
	# --- PNJ A en (3,2), joueur en (2,2) a cote : clic -> il se tourne et on lui parle
	j.placer(Vector2i(2, 2))
	j.direction = Vector2i.UP
	await clic(main, Vector2i(3, 2))
	ok(main.boite.visible and main.texte.text == "Salut." and j.direction == Vector2i.RIGHT, "clic sur un PNJ voisin : le joueur se tourne et lui parle")
	ok(main.pnj_a(Vector2i(3, 2)).direction == Vector2i.LEFT, "le PNJ se tourne vers le joueur")
	await ferme(main)
	# --- clic sur une case vide : rien
	await clic(main, Vector2i(1, 1))
	ok(not main.boite.visible and j.case == Vector2i(2, 2), "clic sur une case sans rien : rien ne se passe")
	# --- clic sur un PNJ lointain : le joueur marche jusqu'a lui puis lui parle (A en (3,2), joueur en (1,1) -> voisin le plus proche)
	j.placer(Vector2i(1, 1))
	await clic(main, Vector2i(3, 2))
	var n := 0
	while not main.boite.visible and n < 60:
		await create_timer(0.05).timeout
		n += 1
	var d: Vector2i = (j.case - Vector2i(3, 2)).abs()
	ok(main.boite.visible and d.x + d.y == 1, "clic sur un PNJ lointain : le joueur arrive a cote (%s) et lui parle" % j.case)
	await ferme(main)
	# --- pancarte en (5,3), joueur en (1,3) : clic -> marche et lit
	j.placer(Vector2i(1, 2))
	j.direction = Vector2i.DOWN
	await clic(main, Vector2i(5, 3))
	n = 0
	while not main.boite.visible and n < 80:
		await create_timer(0.05).timeout
		n += 1
	ok(main.boite.visible and main.texte.text == "ROUTE 1", "clic sur une pancarte lointaine : on marche et on la lit (%s)" % j.case)
	await ferme(main)
	# --- objet au sol en (4,1)
	j.placer(Vector2i(4, 2))
	await clic(main, Vector2i(4, 1))
	ok(main.boite.visible and main.texte.text == "Une POKe BALL." and j.direction == Vector2i.UP, "clic sur un objet voisin")
	await ferme(main)
	# --- une touche de direction annule la marche automatique
	j.placer(Vector2i(1, 1))
	await clic(main, Vector2i(5, 3))
	await create_timer(0.25).timeout
	var avant: Vector2i = j.case
	ok(avant != Vector2i(1, 1), "la marche automatique a demarre (joueur en %s)" % avant)
	Input.action_press("haut")
	await create_timer(0.3).timeout
	Input.action_release("haut")
	await create_timer(0.6).timeout
	ok(not main.boite.visible and j.case.x <= avant.x + 1, "une touche de direction interrompt la marche automatique (de %s a %s)" % [avant, j.case])
	# --- pas de clic pendant un dialogue : le clic avance le dialogue (et ne declenche rien d'autre)
	j.placer(Vector2i(2, 2))
	main.dire(["un", "deux"])
	await clic(main, Vector2i(3, 2))
	ok(main.texte.text == "deux", "pendant un dialogue, le clic fait seulement avancer le texte")
	await ferme(main)
	# --- le clic droit ne fait rien dans le monde
	await clic(main, Vector2i(3, 2), MOUSE_BUTTON_RIGHT)
	ok(not main.boite.visible, "clic droit : rien")
	print("=== ERREURS : ", erreurs)
	quit(1 if erreurs > 0 else 0)
