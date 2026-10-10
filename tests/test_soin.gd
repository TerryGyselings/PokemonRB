extends SceneTree
# Maman soigne l'equipe (apres le starter) ; si tous les Pokemon sont K.O., retour au dernier point de soin
var erreurs := 0
func ok(c: bool, msg: String) -> void:
	print(("OK   " if c else "FAIL ") + msg)
	if not c: erreurs += 1
func action(main) -> void:
	var e := InputEventAction.new()
	e.action = "action"
	e.pressed = true
	main._unhandled_input(e)
func avance(main, max_tours := 400) -> void:
	var n := 0
	while main.evenement_en_cours and n < max_tours:
		if main.boite.visible and not main._choix_actif:
			action(main)
		await create_timer(0.05).timeout
		n += 1
func _init() -> void:
	var main = load("res://scene/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var j = main.joueur
	main.nouvelle_partie(1, "ASH")
	ok(main.point_soin == {"carte": "maison_joueur", "arrivee": [4, 7]}, "point de soin de depart : la maison")
	var arr: Array = main.point_soin["arrivee"]
	main.charger_carte("maison_joueur", Vector2i(8, 4))
	ok(not main.carte.solide(Vector2i(arr[0], arr[1])), "la case d'arrivee du point de soin est libre")
	# --- avant le starter : maman ne soigne pas
	j.direction = Vector2i.UP
	action(main)
	ok(main.boite.visible and not main.evenement_en_cours and main.texte.text.begins_with("Bonjour"), "sans starter : dialogue normal de maman")
	action(main); action(main)
	# --- avec le starter : soin
	main.donner_pokemon("salameche", 5)
	main.equipe[0].pv = 2
	main.equipe[0].attaques[0]["pp"] = 3
	main.poser_drapeau("starter_choisi")
	main.point_soin = {"carte": "bourg_palette", "arrivee": [1, 1]}
	action(main)
	await create_timer(0.1).timeout
	ok(main.evenement_en_cours and main.texte.text.contains("ASH"), "maman parle au joueur par son nom (%s)" % main.texte.text)
	await avance(main)
	var p = main.equipe[0]
	ok(p.pv == p.stats["pv"] and p.attaques[0]["pp"] == p.attaques[0]["pp_max"], "equipe soignee : PV et PP")
	ok(main.point_soin == {"carte": "maison_joueur", "arrivee": [4, 7]}, "le point de soin devient la maison")
	ok(not main.evenement_en_cours and not j.bloque and main.voile.modulate.a == 0.0, "joueur libre, ecran revenu")
	# --- defaite : blackout
	main.combat.auto = true
	main.evenements.chemin_fichier = "res://tests/evenements.json"
	main.charger_carte("bourg_palette", Vector2i(12, -5))
	main.equipe[0].pv = 3
	main.equipe[0].gagner_exp(0)
	main.evenements.jouer("defaite_blackout")
	await avance(main, 800)
	ok(main.carte.id == "maison_joueur" and j.case == Vector2i(4, 7), "tous K.O. : retour a la maison (%s %s)" % [main.carte.id, j.case])
	ok(main.equipe[0].pv == main.equipe[0].stats["pv"], "equipe soignee apres le blackout")
	ok(not main.a_drapeau("apres_combat"), "la suite de l'evenement est annulee")
	ok(not main.evenement_en_cours and not j.bloque, "joueur libre")
	# --- combat d'histoire : pas de blackout
	main.charger_carte("bourg_palette", Vector2i(12, -5))
	main.equipe[0].pv = 3
	main.evenements.jouer("defaite_histoire")
	await avance(main, 800)
	ok(main.carte.id == "bourg_palette" and main.a_drapeau("apres_combat"), "blackout false : l'evenement continue sur place")
	# --- sauvegarde du point de soin
	main.point_soin = {"carte": "bourg_palette", "arrivee": [5, 5]}
	var d: Dictionary = main.exporter()
	main.point_soin = {}
	main.importer(d, 1)
	ok(main.point_soin == {"carte": "bourg_palette", "arrivee": [5, 5]}, "point de soin sauvegarde et recharge")
	print("=== ERREURS : ", erreurs)
	quit(1 if erreurs > 0 else 0)
