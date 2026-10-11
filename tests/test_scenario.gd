extends SceneTree
# Scenario reel : monde continu bourg/Route 1, declencheur au nord du bourg, Chen vient chercher le joueur
# et l'emmene au labo.
var erreurs := 0
func ok(c: bool, msg: String) -> void:
	print(("OK   " if c else "FAIL ") + msg)
	if not c: erreurs += 1
func appuyer(main) -> void:
	var e := InputEventAction.new()
	e.action = "action"
	e.pressed = true
	main._unhandled_input(e)
func _init() -> void:
	load("res://scripts/pokemon.gd").deterministe = true
	var main = load("res://scene/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var j = main.joueur
	# --- monde continu : aucun changement de carte entre le bourg et la Route 1 ---
	main.charger_carte("bourg_palette", Vector2i(12, 3))
	main.poser_drapeau("chen_intro_vu")      # on saute l'evenement pour tester le passage
	for i in 6:
		j.deplacer(Vector2i.UP)
		await create_timer(0.25).timeout
	ok(main.carte.id == "bourg_palette" and main.carte.region_id_a(j.case) == "route_1", "on marche du bourg a la Route 1 sans changer de carte (%s, %s)" % [j.case, main.carte.region_id_a(j.case)])
	ok(not main.evenement_en_cours, "pas d'evenement une fois chen_intro_vu pose")
	main.drapeaux.erase("chen_intro_vu")
	# --- evenement : le joueur arrive en haut du bourg ---
	main.charger_carte("bourg_palette", Vector2i(12, 3))
	ok(main.pnj_a(Vector2i(16, 14)) == null, "Chen n'est pas encore la")
	j.deplacer(Vector2i.UP)                   # (12,2)
	await create_timer(0.25).timeout
	ok(not main.evenement_en_cours, "rien en (12,2)")
	j.deplacer(Vector2i.UP)                   # (12,1) : declencheur
	await create_timer(0.4).timeout
	ok(main.evenement_en_cours and main.a_drapeau("chen_intro_vu"), "l'evenement se declenche en (12,1)")
	appuyer(main)                             # voix
	await create_timer(0.1).timeout
	ok(main.a_drapeau("chen_arrive"), "Chen arrive")
	# Chen marche jusqu'au joueur
	var tours := 0
	while not (main.boite.visible and main.texte.text.begins_with("PROF. CHEN : Il est")) and tours < 80:
		await create_timer(0.1).timeout
		tours += 1
	var chen = null
	for p in main._pnj:
		if p.donnees.get("id", "") == "prof_chen_bourg":
			chen = p
	var d = (chen.case - j.case).abs()
	ok(d.x + d.y == 1, "Chen est arrive a cote du joueur (%s / %s)" % [chen.case, j.case])
	appuyer(main)
	appuyer(main)
	# l'escorte : Chen ouvre la marche vers le labo, le joueur suit
	var suivi := true
	tours = 0
	while main.carte.id != "labo_chen" and tours < 400:
		await create_timer(0.05).timeout
		if is_instance_valid(chen) and main.carte.id != "labo_chen":
			var dd = (chen.case - j.case).abs()
			if dd.x + dd.y > 2:
				suivi = false
		tours += 1
	ok(suivi, "le joueur reste colle derriere Chen pendant l'escorte")
	ok(main.carte.id == "labo_chen", "arrivee au labo")
	await create_timer(0.7).timeout
	ok(main.a_drapeau("scenario_termine"), "scenario_termine")
	var chen2 = null
	for p in main._pnj:
		if p.donnees.get("id", "") == "prof_chen": chen2 = p
	ok(chen2 != null and chen2.case.y >= 8, "Chen entre par la porte et marche (%s)" % [chen2.case if chen2 else null])
	ok(j.case == Vector2i(7, 11), "le joueur attend a la porte pendant que Chen marche (%s)" % j.case)
	await create_timer(2.0).timeout
	ok(chen2.case == Vector2i(7, 2) and chen2.direction == Vector2i.DOWN, "Chen est a sa place et se retourne (%s)" % chen2.case)
	await create_timer(1.6).timeout
	ok(main.pnj_a(Vector2i(7, 2)) != null and main.pnj_a(Vector2i(6, 3)) != null, "prof et rival presents dans le labo")
	ok(j.case == Vector2i(7, 3), "le joueur est alle d'un trait en (7, 3) (%s)" % j.case)
	while main.boite.visible:
		appuyer(main)
		await create_timer(0.1).timeout
	ok(not main.evenement_en_cours and not j.bloque, "joueur libre a la fin")
	print("=== ERREURS : %d" % erreurs)
	quit()
