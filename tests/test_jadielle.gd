extends SceneTree
# Jadielle raccordee a la Route 1, portes des batiments, arene fermee.
var erreurs := 0
func ok(c: bool, msg: String) -> void:
	print(("OK   " if c else "FAIL ") + msg)
	if not c: erreurs += 1
func _chemin(carte, a: Vector2i, b: Vector2i) -> bool:
	# parcours en largeur sans passer par les rebords ni les portes
	var vus := {a: true}
	var file: Array = [a]
	while not file.is_empty():
		var c: Vector2i = file.pop_front()
		if c == b:
			return true
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if vus.has(n) or not carte.dans_carte(n) or carte.solide(n) or carte.sens_unique(n) != Vector2i.ZERO:
				continue
			if carte.porte(n).size() > 0 and n != b:
				continue
			vus[n] = true
			file.append(n)
	return false
func _init() -> void:
	load("res://scripts/pokemon.gd").deterministe = true
	var main = load("res://scene/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.charger_carte("bourg_palette", Vector2i(12, 3))
	var c = main.carte
	ok(c.region_id_a(Vector2i(10, -79)) == "jadielle" and c.region_id_a(Vector2i(10, -41)) == "jadielle", "Jadielle juste au-dessus de la Route 1")
	ok(c.region_id_a(Vector2i(10, -40)) == "route_1", "la Route 1 commence en y=-40")
	ok(c.symbole(Vector2i(10, -41)) == "," and c.symbole(Vector2i(13, -41)) == "," and c.symbole(Vector2i(10, -40)) == ",", "raccord Route 1 / Jadielle : chemin de 4 cases")
	# chemin continu du bourg jusqu'a chaque porte de Jadielle (case juste en dessous)
	var portes: Array = []
	for pos in c._portes:
		if c.region_id_a(pos) == "jadielle":
			portes.append(pos)
	ok(portes.size() == 4, "4 portes dans Jadielle (%d)" % portes.size())
	var depart := Vector2i(12, 8)
	for pos in portes:
		ok(_chemin(c, depart, pos), "le bourg mene a la porte %s -> %s" % [pos, c._portes[pos]["vers"]])
	# l'arene est fermee : porte solide, texte, aucune porte vers elle
	var arene := Vector2i(24, -69)
	ok(c.symbole(arene) == "P" and c.solide(arene), "porte de l'arene fermee (solide)")
	ok(c.interaction(arene).has("texte"), "texte sur la porte de l'arene")
	for pos in c._portes:
		ok(String(c._portes[pos]["vers"]) != "arene_jadielle", "aucune porte exterieure vers l'arene (%s)" % pos)
	# entree / sortie par chaque porte
	for pos in portes:
		var vers := String(c._portes[pos]["vers"])
		var a: Array = c._portes[pos]["arrivee"]
		main.charger_carte(vers, Vector2i(a[0], a[1]))
		ok(main.carte.id == vers and not main.carte.solide(main.joueur.case), "%s : arrivee libre %s" % [vers, main.joueur.case])
		var retour: Dictionary = {}
		for q in main.carte._portes.values():
			if String(q["vers"]) == "jadielle":
				retour = q
		ok(not retour.is_empty(), "%s : porte de sortie vers Jadielle" % vers)
		main.charger_carte("jadielle", Vector2i(retour["arrivee"][0], retour["arrivee"][1]))
		ok(main.carte.region_id_a(main.joueur.case) == "jadielle" and not main.carte.solide(main.joueur.case), "retour dehors en %s" % main.joueur.case)
	print("=== ERREURS : ", erreurs)
	quit(1 if erreurs > 0 else 0)
