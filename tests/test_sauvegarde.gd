extends SceneTree
# Sauvegarde : aller-retour complet (equipe, PP, drapeaux, position, badges...) dans un dossier de test
var erreurs := 0
func ok(c: bool, msg: String) -> void:
	print(("OK   " if c else "FAIL ") + msg)
	if not c: erreurs += 1
func _init() -> void:
	var Sauvegarde := load("res://scripts/sauvegarde.gd")
	Sauvegarde.dossier = "user://test_sauvegardes"
	for s in range(1, 4): Sauvegarde.supprimer(s)
	ok(not Sauvegarde.existe(1) and Sauvegarde.lire(1).is_empty() and Sauvegarde.resume(1) == "- VIDE -", "emplacement vide")
	var main = load("res://scene/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.nouvelle_partie(2, "TERRY")
	ok(main.carte.id == "etage_joueur" and main.nom_joueur == "TERRY" and main.slot_actuel == 2, "nouvelle partie dans la chambre")
	main.donner_pokemon("salameche", 5)
	main.equipe[0].pv = 7
	main.equipe[0].attaques[0]["pp"] = 12
	main.equipe[0].gagner_exp(40)
	main.poser_drapeau("scenario_termine")
	main.badges.append("roche")
	main.argent = 1234
	main.temps_jeu = 3725.0
	main.sac["potion"] = 3
	main.enregistrer_vu("carapuce")
	main.joueur.placer(Vector2i(5, 4))
	main.joueur.direction = Vector2i.LEFT
	ok(Sauvegarde.ecrire(2, main.exporter()), "ecriture")
	ok(Sauvegarde.existe(2) and not Sauvegarde.existe(1), "seul l'emplacement 2 existe")
	print("   resume : ", Sauvegarde.resume(2))
	ok(Sauvegarde.temps_texte(3725.0) == "1:02", "temps 3725 s = 1:02")
	# nouveau jeu vierge qui relit la sauvegarde
	var main2 = load("res://scene/main.tscn").instantiate()
	root.add_child(main2)
	await process_frame
	main2.importer(Sauvegarde.lire(2), 2)
	ok(main2.nom_joueur == "TERRY" and main2.argent == 1234 and main2.badges == ["roche"] and int(main2.temps_jeu) == 3725, "etat du joueur")
	ok(main2.sac == {"potion": 3} and main2.vus.has("carapuce") and main2.captures == ["salameche"], "sac et pokedex")
	var p = main2.equipe[0]
	ok(main2.equipe.size() == 1 and p.espece_id == "salameche" and p.pv == 7 and p.attaques[0]["pp"] == 12 and p.exp == main.equipe[0].exp and p.niveau == main.equipe[0].niveau,
		"equipe : %s Nv%d pv %d exp %d" % [p.nom, p.niveau, p.pv, p.exp])
	ok(main2.a_drapeau("scenario_termine"), "drapeaux")
	ok(main2.carte.id == "etage_joueur" and main2.joueur.case == Vector2i(5, 4) and main2.joueur.direction == Vector2i.LEFT and main2.slot_actuel == 2, "carte, position, direction")
	# fichier corrompu : pas de plantage
	var f := FileAccess.open(Sauvegarde.chemin(3), FileAccess.WRITE)
	f.store_string("{pas du json")
	f.close()
	ok(Sauvegarde.lire(3).is_empty(), "sauvegarde corrompue ignoree")
	for s in range(1, 4): Sauvegarde.supprimer(s)
	print("=== ERREURS : ", erreurs)
	quit(1 if erreurs > 0 else 0)
