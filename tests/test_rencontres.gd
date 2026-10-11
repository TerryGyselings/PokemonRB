extends SceneTree
# Hautes herbes : rencontres sauvages (route 1 / route 22), tirage selon les poids, combat, defaite = blackout
const Donnees := preload("res://scripts/donnees.gd")
var erreurs := 0
func ok(c: bool, msg: String) -> void:
	print(("OK   " if c else "FAIL ") + msg)
	if not c: erreurs += 1
func _init() -> void:
	load("res://scripts/pokemon.gd").deterministe = true
	var main = load("res://scene/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.nouvelle_partie(1, "ASH")
	main.donner_pokemon("salameche", 8)
	main.combat.auto = true
	# --- legende et tables
	var herbe := Vector2i.ZERO
	main.charger_carte("route_1")
	var trouve := false
	for y in range(-60, 0):
		for x in range(0, 20):
			if main.carte.rencontre_a(Vector2i(x, y)) == "herbe":
				herbe = Vector2i(x, y)
				trouve = true
				break
		if trouve: break
	ok(trouve, "la route 1 a des hautes herbes (%s)" % herbe)
	ok(main.carte.rencontre_a(Vector2i(0, 0)) == "", "pas de rencontre sur le chemin")
	var table := Donnees.rencontres("route_1", "herbe")
	ok(not table.is_empty() and table["pokemon"].size() > 0, "table de la route 1")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var vus := {}
	var min_n := 99; var max_n := 0
	for i in 2000:
		var t := Donnees.tirer_rencontre(table, rng)
		vus[t["espece"]] = vus.get(t["espece"], 0) + 1
		min_n = mini(min_n, t["niveau"]); max_n = maxi(max_n, t["niveau"])
	ok(vus.has("roucool") and vus.has("rattata") and vus.size() == 2, "Route 1 : Roucool et Rattata seulement %s" % str(vus))
	ok(min_n >= 2 and max_n <= 5, "niveaux 2 a 5 (%d..%d)" % [min_n, max_n])
	ok(vus["roucool"] > 800 and vus["rattata"] > 800, "poids respectes")
	ok(not Donnees.rencontres("route_22", "herbe").is_empty(), "route 22 : table presente")
	# --- declenchement : taux 100 % force, 0 % jamais
	main.joueur.bloque = false
	main.rng_rencontres.seed = 1
	main.carte.id = "route_1"
	var avant_vus: int = main.vus.size()
	var cases := 0
	var combats := 0
	var sauve = Donnees._lire("rencontres")
	sauve["route_1"]["herbe"]["taux"] = 100
	main.charger_carte("route_1", herbe)
	main.joueur.bloque = false
	main.combat.script_choix = [3]
	var declenche: bool = main._tester_rencontre(herbe)
	ok(declenche, "taux 100 : une rencontre se declenche")
	await create_timer(0.8).timeout
	for i in 100:
		if not main.combat.en_cours: break
		await create_timer(0.1).timeout
	ok(main.vus.size() > avant_vus, "l'espece rencontree est ajoutee au Pokedex (vus=%d)" % main.vus.size())
	ok(not main.joueur.bloque, "le joueur est libere apres le combat")
	sauve["route_1"]["herbe"]["taux"] = 0
	ok(not main._tester_rencontre(herbe), "taux 0 : jamais de rencontre")
	sauve["route_1"]["herbe"]["taux"] = 100
	main.rencontres_actives = false
	ok(not main._tester_rencontre(herbe), "rencontres desactivees")
	main.rencontres_actives = true
	# equipe K.O. : pas de rencontre
	main.equipe[0].pv = 0
	ok(not main._tester_rencontre(herbe), "equipe K.O. : pas de rencontre")
	main.equipe[0].pv = 5
	# --- defaite = blackout (equipe soignee, retour au dernier point de soin)
	main.equipe[0].pv = 1
	var fort = load("res://scripts/pokemon.gd").creer("onix", 40)
	main.combat.script_choix = []
	main.lancer_rencontre(fort)
	for i in 150:
		await create_timer(0.1).timeout
		if main.boite.visible:
			main._avancer_dialogue()
		if main.equipe[0].pv == main.equipe[0].stats["pv"] and not main.combat.en_cours:
			break
	for i in 40:
		await create_timer(0.1).timeout
		if main.boite.visible:
			main._avancer_dialogue()
	ok(main.carte.id == "maison_joueur" or main.carte.id == main.point_soin["carte"], "retour au point de soin (%s)" % main.carte.id)
	ok(main.equipe[0].pv == main.equipe[0].stats["pv"], "blackout : equipe soignee")
	print("ERREURS : ", erreurs)
	quit(1 if erreurs > 0 else 0)
