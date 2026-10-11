extends SceneTree
# Declencheur sur hautes herbes -> evenement : dialogue, PNJ qui arrive et marche, changement de carte, drapeaux
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
	main.carte.dossier = "res://tests/cartes"
	main.carte.fichier_monde = ""
	main.evenements.chemin_fichier = "res://tests/evenements.json"
	main.charger_carte("evt")
	var j = main.joueur
	j.placer(Vector2i(3, 2))
	ok(not main.a_drapeau("vu"), "pas encore declenche")
	j.deplacer(Vector2i.RIGHT)          # (4,2) = hautes herbes
	await create_timer(0.4).timeout
	ok(main.a_drapeau("vu") and main.evenement_en_cours, "declencheur : evenement lance")
	ok(main.boite.visible and main.texte.text == "Qui va la ?", "premier dialogue")
	ok(j.bloque, "joueur bloque pendant l'evenement")
	appuyer(main)
	await create_timer(0.1).timeout
	ok(main.pnj_a(Vector2i(7, 1)) != null or main.a_drapeau("arrive"), "le PNJ apparait")
	await create_timer(1.5).timeout
	var chen = main._pnj[0]
	var voisin: bool = (chen.case - j.case).abs().x + (chen.case - j.case).abs().y == 1
	ok(voisin, "le PNJ a marche jusqu'a cote du joueur (%s / joueur %s)" % [chen.case, j.case])
	ok(main.boite.visible and main.texte.text == "Suis-moi.", "dialogue du PNJ")
	appuyer(main)
	ok(main.texte.text == "Page 2.", "page 2")
	appuyer(main)
	await create_timer(0.8).timeout
	ok(main.carte.id == "rdc" and j.case == Vector2i(3, 1), "changement de carte (%s %s)" % [main.carte.id, j.case])
	ok(main.a_drapeau("fin") and not main.evenement_en_cours and not j.bloque, "fin : drapeau pose, joueur libre")
	# l'evenement ne se relance pas (si_pas)
	main.charger_carte("evt")
	j.placer(Vector2i(3, 2))
	j.deplacer(Vector2i.RIGHT)
	await create_timer(0.4).timeout
	ok(not main.evenement_en_cours and not main.boite.visible, "ne se relance pas")
	# marche continue : 6 cases en un trait, sans pause entre les pas
	main.drapeaux.clear()
	main.charger_carte("evt")
	j.placer(Vector2i(1, 3))
	var debut := Time.get_ticks_msec()
	main.evenements.jouer("marche")
	while not main.a_drapeau("arrive_au_bout") and Time.get_ticks_msec() - debut < 4000:
		await create_timer(0.02).timeout
	var duree := (Time.get_ticks_msec() - debut) / 1000.0
	ok(j.case == Vector2i(7, 3), "joueur_vers : le joueur arrive en %s" % j.case)
	ok(duree < 6 * 0.16 + 0.35, "marche continue : %.2f s pour 6 cases (pas de pause entre les pas)" % duree)
	print("=== ERREURS : %d" % erreurs)
	quit()
