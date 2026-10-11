extends SceneTree
# Ecran titre : appuyer sur un bouton, NOUVELLE PARTIE (emplacement + nom), puis CONTINUER avec une sauvegarde
var erreurs := 0
func ok(c: bool, msg: String) -> void:
	print(("OK   " if c else "FAIL ") + msg)
	if not c: erreurs += 1
func lance():
	var main = load("res://scene/main.tscn").instantiate()
	main.avec_titre = true
	root.add_child(main)
	await process_frame
	await process_frame
	return main
func touche(main, nom: String) -> void:
	main.titre.appuyer(nom)
	await process_frame
func tape(main, texte: String) -> void:
	for c in texte:
		var e := InputEventKey.new()
		e.pressed = true
		e.unicode = c.unicode_at(0)
		e.keycode = c.unicode_at(0)
		main.titre.clavier.emit(e)
		await process_frame
func entree(main) -> void:
	var e := InputEventKey.new()
	e.pressed = true
	e.keycode = KEY_ENTER
	main.titre.clavier.emit(e)
	await process_frame
func _init() -> void:
	load("res://scripts/pokemon.gd").deterministe = true
	var Sauvegarde := load("res://scripts/sauvegarde.gd")
	Sauvegarde.dossier = "user://test_sauvegardes"
	for s in range(1, 4): Sauvegarde.supprimer(s)
	var main = await lance()
	ok(main.titre != null and main.titre.actif and not main.partie_en_cours and main.joueur.bloque, "l'ecran titre est affiche, le jeu attend")
	await create_timer(1.5).timeout    # l'animation tourne
	await touche(main, "action")        # appuyer sur un bouton
	# menu : CONTINUER grise (pas de sauvegarde), le curseur est sur NOUVELLE PARTIE
	await touche(main, "action")
	await touche(main, "bas")           # 3 emplacements
	await touche(main, "action")        # emplacement 2
	await tape(main, "terry 7")
	await entree(main)
	await process_frame
	ok(main.partie_en_cours and main.nom_joueur == "TERRY 7" and main.slot_actuel == 2, "nouvelle partie : emplacement 2, nom %s" % main.nom_joueur)
	ok(main.carte.id == "etage_joueur" and not main.joueur.bloque, "le jeu demarre dans la chambre, joueur libre")
	ok(main.equipe.is_empty() and main.argent == 3000, "equipe vide, 3000 P")
	main.donner_pokemon("bulbizarre", 5)
	Sauvegarde.ecrire(2, main.exporter())
	main.queue_free()
	await process_frame
	# deuxieme lancement : CONTINUER
	main = await lance()
	await touche(main, "action")
	await touche(main, "action")        # CONTINUER (curseur place dessus)
	await touche(main, "action")        # 1er emplacement non vide = 2
	await process_frame
	ok(main.partie_en_cours and main.nom_joueur == "TERRY 7" and main.slot_actuel == 2 and main.equipe.size() == 1, "continuer : partie chargee (%s, slot %d)" % [main.nom_joueur, main.slot_actuel])
	main.queue_free()
	await process_frame
	# nouvelle partie sur un emplacement occupe : demande de confirmation (NON -> retour au menu)
	main = await lance()
	await touche(main, "action")
	await touche(main, "bas")
	await touche(main, "action")        # NOUVELLE PARTIE
	await touche(main, "bas")
	await touche(main, "action")        # emplacement 2 (occupe)
	await touche(main, "bas")
	await touche(main, "action")        # NON
	ok(not main.partie_en_cours, "NON : on reste sur l'ecran titre")
	await touche(main, "annuler")
	await touche(main, "annuler")       # retour a l'ecran d'accueil
	ok(not main.partie_en_cours, "retour a l'ecran d'accueil")
	for s in range(1, 4): Sauvegarde.supprimer(s)
	print("=== ERREURS : ", erreurs)
	quit(1 if erreurs > 0 else 0)
