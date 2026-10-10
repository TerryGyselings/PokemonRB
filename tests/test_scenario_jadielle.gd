extends SceneTree
# Scenario de Jadielle : vieil homme qui bloque, colis de la boutique, retour au labo (POKeDEX),
# demonstration de capture, boutique ouverte (achat / vente).
var erreurs := 0
func ok(c: bool, msg: String) -> void:
	print(("OK   " if c else "FAIL ") + msg)
	if not c: erreurs += 1
func touche(main, nom: String) -> void:
	var e := InputEventAction.new()
	e.action = nom
	e.pressed = true
	main._unhandled_input(e)
# fait defiler les dialogues tant que "cond" n'est pas vraie (ou jusqu'a la limite)
func jusqu_a(main, cond: Callable, max_tours := 900) -> void:
	var n := 0
	while not cond.call() and n < max_tours:
		if main.boite.visible and not main._choix_actif:
			touche(main, "action")
		await create_timer(0.05).timeout
		n += 1
func libre(main) -> bool:
	return not main.evenement_en_cours and not main.joueur.en_marche() and not main._transition
func pas(main, s: Callable) -> void:
	await create_timer(0.06).timeout
func b(main, nom: String) -> void:
	main.boutique.appuyer(nom)
	await create_timer(0.06).timeout
func _init() -> void:
	var main = load("res://scene/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var j = main.joueur
	main.combat.auto = true
	for f in ["chen_intro_vu", "scenario_termine", "starter_choisi", "combat_rival_fait", "rival_parti"]:
		main.poser_drapeau(f)
	main.donner_pokemon("salameche", 5)
	# ---- 1. le vieil homme bloque le col (ligne 11 de Jadielle = y -68 dans le monde ; cases x 20..22 = monde 8..10)
	main.charger_carte("jadielle", Vector2i(8, -67))
	var vieux = main.pnj_a(Vector2i(9, -68))
	ok(vieux != null and vieux.donnees["id"] == "jadielle_vieil_homme", "avant le POKeDEX : le vieil homme est en (21,11)")
	ok(main.pnj_a(Vector2i(9, -73)) == null, "le vieil homme du tuto n'est pas encore la")
	j.direction = Vector2i.UP
	j.deplacer(Vector2i.UP)
	await jusqu_a(main, func(): return main.boite.visible)
	ok(main.evenement_en_cours and main.texte.text.begins_with("VIEIL HOMME : Hé là"), "arrivee sur la ligne 11 : il t'arrete")
	await jusqu_a(main, func(): return libre(main))
	ok(j.case == Vector2i(8, -67), "le joueur est repousse d'une case vers le bas (%s)" % j.case)
	main.charger_carte("jadielle", Vector2i(10, -67))
	j.deplacer(Vector2i.UP)
	await jusqu_a(main, func(): return main.boite.visible)
	await jusqu_a(main, func(): return libre(main))
	ok(j.case == Vector2i(10, -67), "x=22 aussi bloque")
	main.charger_carte("jadielle", Vector2i(9, -67))
	ok(not j.deplacer(Vector2i.UP), "au milieu : le vieil homme lui-meme barre la route")
	# ---- 2. a gauche : bloque aussi
	main.charger_carte("jadielle", Vector2i(-10, -62))
	j.deplacer(Vector2i.LEFT)
	await jusqu_a(main, func(): return main.boite.visible)
	await jusqu_a(main, func(): return libre(main))
	ok(j.case == Vector2i(-10, -62), "sortie ouest bloquee : le joueur revient (%s)" % j.case)
	# ---- 3. boutique : le vendeur t'interpelle, le colis
	main.charger_carte("jadielle", Vector2i(24, -59))
	main._passer_porte(main.carte.porte(Vector2i(24, -60)))
	await jusqu_a(main, func(): return main.a_drapeau("colis_recupere") and libre(main), 1500)
	ok(main.carte.id == "boutique_jadielle", "dans la boutique")
	ok(main.sac.get("colis_chen", 0) == 1 and main.a_drapeau("colis_recupere"), "colis du Prof. CHEN dans le sac")
	ok(j.case == Vector2i(3, 4) and j.direction == Vector2i.UP, "le joueur a marche jusqu'au comptoir (%s)" % j.case)
	# on ressort et on revient : plus de scene
	main._passer_porte(main.carte.porte(Vector2i(5, 7)))
	await jusqu_a(main, func(): return main.carte.id == "jadielle" and libre(main), 200)
	main._passer_porte(main.carte.porte(Vector2i(24, -60)))
	await jusqu_a(main, func(): return main.carte.id == "boutique_jadielle" and libre(main), 200)
	ok(not main.evenement_en_cours and j.case == Vector2i(5, 6), "2e entree : pas de nouvelle scene")
	# vendeur : boutique pas encore ouverte
	j.placer(Vector2i(3, 4)); j.direction = Vector2i.UP
	main._interagir(j.case + j.direction)
	await jusqu_a(main, func(): return libre(main))
	ok(not main.boutique.actif, "boutique fermee avant la demonstration de capture")
	# ---- 4. retour au labo : pokedex
	main.charger_carte("bourg_palette", Vector2i(16, 14))
	main._passer_porte(main.carte.porte(Vector2i(16, 13)))
	await jusqu_a(main, func(): return main.a_drapeau("pokedex_obtenu"), 2000)
	var rv = main.pnj_a(Vector2i(6, 3))
	ok(rv != null and rv.donnees["id"] == "rival_pokedex" and j.case == Vector2i(7, 3) and main.pnj_a(Vector2i(8, 3)) == null, "le rival est a GAUCHE du joueur quand le POKeDEX est donne")
	await jusqu_a(main, func(): return libre(main), 2000)
	ok(main.carte.id == "labo_chen", "dans le labo")
	ok(main.a_drapeau("colis_livre") and not main.sac.has("colis_chen"), "colis remis au professeur")
	ok(j.case == Vector2i(7, 3), "le joueur est devant le professeur (%s)" % j.case)
	ok(main.a_drapeau("pokedex_obtenu"), "POKeDEX obtenu")
	ok(main.pnj_a(Vector2i(8, 3)) == null and main.pnj_a(Vector2i(7, 10)) == null, "le rival est reparti")
	var textes: Array = main.menu_jeu._options().map(func(x): return x[0])
	ok(textes.has("pokedex"), "le menu propose le POKeDEX")
	# ---- 5. le vieil homme montre la capture
	var caps0: int = main.captures.size()
	main.charger_carte("jadielle", Vector2i(8, -72))
	ok(main.pnj_a(Vector2i(9, -68)) == null and main.pnj_a(Vector2i(9, -73)) != null, "apres le POKeDEX : le vieil homme est en (21,6)")
	j.deplacer(Vector2i.UP)
	await jusqu_a(main, func(): return main.a_drapeau("capture_montree") and libre(main), 2000)
	ok(main.a_drapeau("capture_montree"), "demonstration de capture faite")
	var jr: String = " | ".join(main.combat.journal)
	ok(jr.contains("sauvage") and jr.contains("capture"), "la demonstration est passee par l'ecran de combat")
	ok(main.captures.size() == caps0 and main.equipe.size() == 1 and not main.combat.en_cours, "rien n'est ajoute a l'equipe ni au Pokedex")
	var v2 = main.pnj_a(Vector2i(9, -73))
	ok(v2 != null, "le vieil homme est retourne a sa place")
	# plus de blocage
	main.charger_carte("jadielle", Vector2i(8, -72))
	j.deplacer(Vector2i.UP)
	await create_timer(0.3).timeout
	j.deplacer(Vector2i.UP)
	await create_timer(0.3).timeout
	ok(j.case == Vector2i(8, -74) and not main.evenement_en_cours, "le col est libre (%s)" % j.case)
	main.charger_carte("jadielle", Vector2i(-10, -62))
	j.deplacer(Vector2i.LEFT)
	await create_timer(0.3).timeout
	ok(j.case == Vector2i(-11, -62) and not main.evenement_en_cours, "la sortie ouest n'est plus bloquee")
	# ---- 6. boutique ouverte : achat puis vente
	main.charger_carte("boutique_jadielle", Vector2i(3, 4))
	j.direction = Vector2i.UP
	main._interagir(j.case + j.direction)
	await jusqu_a(main, func(): return main.boutique.actif)
	ok(main.boutique.actif, "la boutique s'ouvre")
	await create_timer(0.1).timeout
	await b(main, "action")      # ACHETER
	await b(main, "action")      # POKe BALL
	await b(main, "haut")
	await b(main, "haut")        # quantite 3
	await b(main, "action")
	await b(main, "action")      # OUI
	ok(main.argent == 3000 - 600 and main.sac.get("poke_ball", 0) == 3, "achat de 3 POKe BALLS (argent %d)" % main.argent)
	await b(main, "action")      # "Voila ! Merci"
	await b(main, "annuler")     # retour au menu
	await b(main, "bas")
	await b(main, "action")      # VENDRE
	await b(main, "action")      # POKe BALL
	await b(main, "haut")        # quantite 2
	await b(main, "action")
	await b(main, "action")      # OUI
	ok(main.argent == 3000 - 600 + 200 and main.sac.get("poke_ball", 0) == 1, "vente de 2 POKe BALLS a 100 P (argent %d)" % main.argent)
	await b(main, "action")
	await b(main, "annuler")
	await b(main, "annuler")     # SORTIR
	await b(main, "action")      # "A bientot"
	await create_timer(0.2).timeout
	ok(not main.boutique.actif, "boutique refermee")
	# 10 POKe BALLS = 1 HONOR BALL en bonus
	main.argent = 3000
	j.direction = Vector2i.UP
	main._interagir(j.case + j.direction)
	await jusqu_a(main, func(): return main.boutique.actif)
	await create_timer(0.1).timeout
	await b(main, "action")      # ACHETER
	await b(main, "action")      # POKe BALL
	for i in 9: await b(main, "haut")     # quantite 10
	await b(main, "action")
	await b(main, "action")      # OUI
	ok(main.argent == 1000 and main.sac.get("poke_ball", 0) == 11, "10 POKe BALLS achetees (argent %d)" % main.argent)
	await b(main, "action")      # Voila
	ok(main.sac.get("honor_ball", 0) == 1, "1 HONOR BALL en bonus")
	await b(main, "action")      # En bonus
	await b(main, "annuler")
	await b(main, "annuler")
	await b(main, "action")
	await create_timer(0.2).timeout
	ok(not main.boutique.actif, "boutique refermee (2)")
	# pas assez d'argent
	main.argent = 100
	j.direction = Vector2i.UP
	main._interagir(j.case + j.direction)
	await jusqu_a(main, func(): return main.boutique.actif)
	await create_timer(0.1).timeout
	await b(main, "action")
	await b(main, "action")      # POKe BALL (200 P) : trop cher
	ok(main.argent == 100 and main.sac.get("poke_ball", 0) == 11, "pas assez d'argent : rien n'est achete")
	await b(main, "action")      # message
	await b(main, "annuler")
	await b(main, "annuler")
	await b(main, "action")
	await create_timer(0.2).timeout
	ok(not main.boutique.actif, "boutique refermee (3)")
	# ---- 7. la soeur du rival donne la carte apres le starter
	var s2 = main.sac.duplicate()
	main.charger_carte("maison_rival", Vector2i(9, 5))
	j.direction = Vector2i.UP
	main.drapeaux.erase("starter_choisi")
	main._interagir(j.case + j.direction)
	await jusqu_a(main, func(): return libre(main))
	ok(not main.sac.has("carte_region"), "sans starter : pas de carte")
	main.poser_drapeau("starter_choisi")
	main._interagir(j.case + j.direction)
	await jusqu_a(main, func(): return main.a_drapeau("carte_recue") and libre(main))
	ok(main.sac.get("carte_region", 0) == 1, "avec le starter : la soeur du rival donne la CARTE")
	main._interagir(j.case + j.direction)
	await jusqu_a(main, func(): return libre(main))
	ok(main.sac.get("carte_region", 0) == 1, "une seule carte")
	# ---- 8. le tuto se declenche sur toute la ligne 6 (ici x=30) et sur la colonne ouest (x=8)
	for dep in [Vector2i(18, -72)]:
		main.drapeaux.erase("capture_montree")
		main.charger_carte("jadielle", dep)
		j.deplacer(Vector2i.UP)
		await jusqu_a(main, func(): return main.a_drapeau("capture_montree") and libre(main), 2000)
		ok(main.a_drapeau("capture_montree"), "tuto declenche depuis %s" % dep)
	print("=== ERREURS : ", erreurs)
	quit(1 if erreurs > 0 else 0)
