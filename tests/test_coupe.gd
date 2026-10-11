extends SceneTree
var erreurs := 0
func ok(c: bool, msg: String) -> void:
	print(("OK   " if c else "FAIL ") + msg)
	if not c: erreurs += 1
func ferme(main) -> void:
	var n := 0
	while main.boite.visible and n < 60:
		var e := InputEventAction.new()
		e.action = "action"
		e.pressed = true
		main._unhandled_input(e)
		await process_frame
		n += 1
func attendre(main, f: Callable, max := 100) -> void:
	var n := 0
	while not f.call() and n < max:
		await create_timer(0.05).timeout
		n += 1
func _init() -> void:
	load("res://scripts/pokemon.gd").deterministe = true
	var main = load("res://scene/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var j = main.joueur
	# --- pagination
	var t := "VIEIL HOMME : Mmh, mon café commence à faire effet... Bon, je suis pressé, mais je vais te montrer comment on capture un POKéMON !"
	var pages: Array = main._paginer(t)
	ok(pages.size() >= 2, "texte long coupe en %d pages" % pages.size())
	ok(pages[0].begins_with("VIEIL HOMME : Mmh"), "1ere page commence bien")
	for p in pages: ok(p.count("\n") <= 1, "page <= 2 lignes : %s" % p.replace("\n", "|"))
	# --- coupe : on remplace une case d'herbe de la route 1 par un arbuste 'a'
	main.charger_carte("route_1", Vector2i(2, -30))
	var reg: Dictionary = main.carte._regions[0]
	var cible := Vector2i(-1, -1)
	for y in range(reg["hauteur"]):
		var ligne: String = reg["lignes"][y]
		for x in range(1, ligne.length() - 1):
			if ligne[x] == "." and ligne[x - 1] == "." and ligne[x + 1] == ".":
				cible = Vector2i(x, y)
				break
		if cible.x >= 0: break
	ok(cible.x >= 0, "case libre trouvee %s" % cible)
	var l: String = reg["lignes"][cible.y]
	reg["lignes"][cible.y] = l.substr(0, cible.x) + "a" + l.substr(cible.x + 1)
	var w: Vector2i = reg["origine"] + cible
	ok(main.carte.solide(w), "arbuste solide")
	ok(main.carte.est_coupable(w), "arbuste coupable")
	ok(not main.carte.est_coupable(w + Vector2i.RIGHT), "voisin non coupable")
	ok(main._interactif(w), "curseur main sur l'arbuste")
	# sans capacite : simple message
	j.case = w + Vector2i.LEFT
	main._interagir(w)
	await process_frame
	ok(main.boite.visible and "pouvoir" in main.texte.text, "sans COUPE : message (%s)" % main.texte.text)
	await ferme(main)
	ok(main.carte.solide(w), "toujours la")
	# avec capacite : on accepte
	main.poser_drapeau("capacite_coupe")
	main._interagir(w)
	await attendre(main, func(): return main.boite.visible and "Utiliser" in main.texte.text)
	ok("Utiliser COUPE" in main.texte.text, "question posee")
	var e := InputEventAction.new()
	e.action = "action"
	e.pressed = true
	main._unhandled_input(e)
	await attendre(main, func(): return main.carte.symbole(w) == ".")
	await ferme(main)
	ok(main.carte.symbole(w) == ".", "arbuste coupe -> herbe")
	ok(not main.carte.solide(w), "plus solide")
	ok(not main.carte.est_coupable(w), "plus coupable")
	var cle := "coupe@route_1@%d,%d" % [cible.x, cible.y]
	ok(main.a_drapeau(cle), "drapeau %s" % cle)
	ok(not main.joueur.bloque, "joueur libere")
	# persistance : rechargement de la carte (la modif de lignes disparait, la coupe ne doit pas poser de probleme)
	var d: Dictionary = main.exporter()
	ok(d["drapeaux"].has(cle), "drapeau dans la sauvegarde")
	main.charger_carte("route_1", Vector2i(2, -30))
	ok(main.carte.cases_coupees.has(w), "coupe restauree au rechargement")
	# Pokemon connaissant coupe
	main.drapeaux.erase("capacite_coupe")
	ok(main.qui_coupe() == "", "personne ne coupe")
	main.equipe[0].attaques.append({"id": "coupe", "pp": 30, "pp_max": 30}) if not main.equipe.is_empty() else null
	if not main.equipe.is_empty():
		ok(main.qui_coupe() == String(main.equipe[0].nom).to_upper(), "le Pokemon avec COUPE coupe")
	print("ERREURS: ", erreurs)
	quit(1 if erreurs > 0 else 0)
