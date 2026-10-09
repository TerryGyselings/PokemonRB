extends SceneTree
# Choix du starter dans le labo (OUI / NON), le rival prend l'autre, puis combat a la sortie.
var erreurs := 0
func ok(c: bool, msg: String) -> void:
	print(("OK   " if c else "FAIL ") + msg)
	if not c: erreurs += 1
func touche(main, nom: String) -> void:
	var e := InputEventAction.new()
	e.action = nom
	e.pressed = true
	main._unhandled_input(e)
# fait defiler les dialogues jusqu'a la fin de l'evenement (ou le debut d'un combat)
func avancer(main, max_tours := 600) -> void:
	var n := 0
	while main.evenement_en_cours and not main.combat.en_cours and n < max_tours:
		if main.boite.visible and not main._choix_actif:
			touche(main, "action")
		await create_timer(0.05).timeout
		n += 1
func _init() -> void:
	var main = load("res://scene/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var j = main.joueur
	main.charger_carte("labo_chen", Vector2i(9, 4))
	j.direction = Vector2i.UP
	# avant l'ouverture du choix : la balle n'est qu'un objet
	touche(main, "action")
	ok(main.boite.visible and not main.evenement_en_cours, "avant l'autorisation : simple texte")
	touche(main, "action")
	main.poser_drapeau("scenario_termine")
	main.poser_drapeau("choix_starter_ouvert")
	ok(main.pnj_a(Vector2i(9, 3)) != null and main.pnj_a(Vector2i(10, 3)) != null and main.pnj_a(Vector2i(11, 3)) != null, "trois balles sur la table")
	# NON
	touche(main, "action")
	await create_timer(0.1).timeout
	ok(main._choix_actif, "question OUI/NON affichee")
	touche(main, "bas")
	touche(main, "action")
	await avancer(main)
	ok(main.equipe.is_empty() and not main.a_drapeau("starter_choisi") and main.pnj_a(Vector2i(9, 3)) != null, "NON : rien ne change")
	# OUI
	touche(main, "action")
	await create_timer(0.1).timeout
	touche(main, "action")
	await avancer(main)
	ok(main.equipe.size() == 1 and main.equipe[0].espece_id == "salameche" and main.equipe[0].niveau == 5, "Salameche Nv5 dans l'equipe")
	ok(main.a_drapeau("starter_choisi") and main.a_drapeau("starter_salameche"), "drapeaux starter")
	ok(main.pnj_a(Vector2i(9, 3)) == null, "la balle de Salameche a disparu")
	ok(main.pnj_a(Vector2i(10, 3)) == null, "le rival a pris Carapuce")
	ok(main.pnj_a(Vector2i(11, 3)) != null, "Bulbizarre reste sur la table")
	var rival = null
	for p in main._pnj:
		if p.donnees.get("id", "") == "rival": rival = p
	ok(rival != null and rival.case == Vector2i(10, 4), "le rival est devant sa balle (%s)" % [rival.case if rival else null])
	ok(not main.evenement_en_cours and not j.bloque, "joueur libre")
	# les balles ne servent plus
	j.placer(Vector2i(11, 4)); j.direction = Vector2i.UP
	touche(main, "action")
	ok(main.boite.visible and not main.evenement_en_cours, "balle restante : texte seulement")
	touche(main, "action")
	# sortie du labo -> defi du rival
	main.equipe[0].pv = 3
	j.placer(Vector2i(7, 8))
	j.deplacer(Vector2i.UP)
	var n := 0
	while not main.combat.en_cours and n < 400:
		if main.boite.visible: touche(main, "action")
		await create_timer(0.05).timeout
		n += 1
	ok(main.combat.en_cours, "le combat contre le rival commence")
	ok(main.combat.actif_e.espece_id == "carapuce" and main.combat.actif_e.niveau == 5, "le rival a Carapuce Nv5")
	# on joue au clavier : action = valider (COMBAT puis 1re attaque, ou avancer un message)
	n = 0
	while main.combat.en_cours and n < 1500:
		main.combat.appuyer("action")
		await create_timer(0.04).timeout
		n += 1
	ok(not main.combat.en_cours, "le combat est termine (%d tours de boucle)" % n)
	print("   dernier message : ", main.combat.journal[-1], " / victoire = ", main.a_drapeau("combat_rival_gagne"))
	await avancer(main)
	ok(main.a_drapeau("combat_rival_fait") and main.a_drapeau("rival_parti"), "suite du scenario jouee")
	ok(main.pnj_a(Vector2i(7, 11)) == null and not main._pnj.any(func(p): return p.donnees.get("id", "") == "rival"), "le rival est parti")
	ok(main.equipe[0].pv == main.equipe[0].stats["pv"], "equipe soignee apres le combat")
	ok(not main.evenement_en_cours and not j.bloque, "joueur libre a la fin")
	# le defi ne se redeclenche pas
	j.placer(Vector2i(7, 8))
	j.deplacer(Vector2i.UP)
	await create_timer(0.4).timeout
	ok(not main.evenement_en_cours, "pas de second defi")
	print("=== ERREURS : ", erreurs)
	quit(1 if erreurs > 0 else 0)
