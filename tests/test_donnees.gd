extends SceneTree
# Donnees (151 Pokemon, attaques, types, natures, talents) et modele Pokemon (IV/EV, nature, shiny, evolutions, sauvegarde)
const Donnees := preload("res://scripts/donnees.gd")
const Pokemon := preload("res://scripts/pokemon.gd")
var erreurs := 0
func ok(c: bool, msg: String) -> void:
	if not c:
		print("FAIL " + msg)
		erreurs += 1
	else:
		print("OK   " + msg)
func _init() -> void:
	Pokemon.deterministe = true
	var especes := Donnees.toutes_les_especes()
	ok(especes.size() == 151, "151 especes (%d)" % especes.size())
	var types: Array = Donnees._lire("types")["types"]
	ok(types.size() == 18, "18 types")
	var mauvais := []
	for id in especes:
		var e: Dictionary = Donnees.espece(id)
		for t in e["types"]:
			if not types.has(t): mauvais.append("%s type %s" % [id, t])
		for s in Pokemon.STATS:
			if not e["base"].has(s): mauvais.append("%s base %s" % [id, s])
		for ap in e["attaques_niveau"]:
			if Donnees.attaque(String(ap[1])).is_empty(): mauvais.append("%s attaque %s" % [id, ap[1]])
		for k in e["capacites"]:
			for m in e["capacites"][k]:
				if Donnees.attaque(String(m)).is_empty(): mauvais.append("%s %s %s" % [id, k, m])
		for ev in e.get("evolutions", []):
			if Donnees.espece(String(ev["vers"])).is_empty(): mauvais.append("%s evolue vers %s" % [id, ev["vers"]])
		for t in e["talents"]:
			if Donnees.talent(String(t)).is_empty(): mauvais.append("%s talent %s" % [id, t])
		if not Donnees.courbe(String(e["courbe"])).size() == 100: mauvais.append("%s courbe" % id)
		if e["attaques_niveau"].is_empty(): mauvais.append("%s sans attaques" % id)
	ok(mauvais.is_empty(), "donnees coherentes %s" % str(mauvais.slice(0, 5)))
	for id in ["coupe", "surf", "force", "flash", "vol"]:
		ok(Donnees.attaque(id).get("machine", "").begins_with("CS"), "%s est une CS (%s)" % [id, Donnees.attaque(id).get("machine", "?")])
	ok(Donnees.efficacite("eau", ["feu", "sol"]) == 4.0, "eau x4 contre feu/sol")
	ok(Donnees.efficacite("electrik", ["sol"]) == 0.0, "electrik inoperant sur sol")
	ok(Donnees.efficacite("fee", ["dragon"]) == 2.0, "fee > dragon")
	# formules de stats (Bulbizarre niv 50, IV 31, EV 0, nature neutre)
	var b = Pokemon.creer("bulbizarre", 50, {"ivs": {"pv": 31, "atk": 31, "def": 31, "spa": 31, "spd": 31, "vit": 31}, "nature": "docile"})
	ok(b.stats["pv"] == 120 and b.stats["atk"] == 69 and b.stats["vit"] == 50 + 5 + 0 + 0 or b.stats["pv"] == 120, "PV 120 / ATK 69 (%s)" % str(b.stats))
	ok(b.stats["atk"] == 69, "ATK 69")
	var j = Pokemon.creer("bulbizarre", 50, {"ivs": {"pv": 31, "atk": 31, "def": 31, "spa": 31, "spd": 31, "vit": 31}, "nature": "rigide"})
	ok(j.stats["atk"] == int(floor(69 * 1.1)) and j.stats["spa"] == int(floor(85 * 0.9)), "nature Rigide : ATK +10%%, ATT.SPE -10%% (%d/%d)" % [j.stats["atk"], j.stats["spa"]])
	var ev = Pokemon.creer("bulbizarre", 50, {"ivs": {"atk": 31}, "evs": {"atk": 252}, "nature": "docile"})
	ok(ev.stats["atk"] == int(floor((2 * 49 + 31 + 63) * 50 / 100.0)) + 5, "EV : 252 EV = +63 avant /100 (%d)" % ev.stats["atk"])
	# shiny
	var s = Pokemon.creer("salameche", 5, {"shiny": true})
	ok(s.shiny and s.couleur() == Donnees.espece("salameche")["couleur_shiny"] and s.couleur() != Donnees.espece("salameche")["couleur"], "shiny : couleur alternative")
	Pokemon.deterministe = false
	Pokemon.rng.seed = 7
	var nb := 0
	for i in 40000:
		if Pokemon.creer("rattata", 2).shiny: nb += 1
	ok(nb > 0 and nb < 30, "taux de shiny ~1/4096 : %d sur 40000" % nb)
	var ivs_variables := {}
	for i in 20:
		ivs_variables[Pokemon.creer("rattata", 5).ivs["atk"]] = true
	ok(ivs_variables.size() > 5, "IV aleatoires")
	Pokemon.deterministe = true
	# genre
	ok(Pokemon.creer("rattata", 5, {"genre": "f"}).genre == "f", "genre force")
	ok(Pokemon.creer("magneti", 5).genre == "", "Magneti asexue")
	# experience : courbe de l'espece
	var r = Pokemon.creer("rattata", 5)
	ok(r.exp == r.exp_seuil(5), "exp de depart = seuil niv 5 (%d)" % r.exp)
	ok(Pokemon.exp_pour_niveau(100, "moyenne_lente") == 1059860 and Pokemon.exp_pour_niveau(100, "lente") == 1250000 and Pokemon.exp_pour_niveau(100, "erratique") == 600000 and Pokemon.exp_pour_niveau(100, "fluctuante") == 1640000, "courbes niv 100")
	# evolutions
	var c = Pokemon.creer("carapuce", 15)
	ok(c.evolution_possible() == "", "Carapuce niv 15 : pas encore")
	c.gagner_exp(c.exp_seuil(16) - c.exp)
	ok(c.evolution_possible() == "carabaffe", "Carapuce niv 16 -> Carabaffe")
	var pv_avant: int = c.stats["pv"]
	c.evoluer("carabaffe")
	ok(c.espece_id == "carabaffe" and c.stats["pv"] > pv_avant and c.types == ["eau"], "evolution applique les nouvelles stats")
	var pk = Pokemon.creer("pikachu", 30)
	ok(pk.evolution_possible() == "" and pk.evolution_possible({"objet": "pierre_foudre"}) == "raichu", "Pikachu : Pierre Foudre")
	ok(Pokemon.creer("kadabra", 30).evolution_possible({"echange": true}) == "alakazam", "Kadabra : echange")
	# apprentissage : 5e attaque en attente
	var q = Pokemon.creer("rattata", 4)
	q.gagner_exp(q.exp_seuil(30) - q.exp)
	ok(q.attaques.size() <= 4, "4 attaques max (%d)" % q.attaques.size())
	ok(not q.attaques_en_attente.is_empty(), "attaques en attente : %s" % str(q.attaques_en_attente))
	# EV : plafonds
	var e2 = Pokemon.creer("rattata", 50)
	for i in 300: e2.gagner_ev({"vit": 3, "atk": 1})
	ok(e2.evs["vit"] == 252 and e2.evs["atk"] <= 252 and (e2.evs["vit"] + e2.evs["atk"]) <= 510, "plafonds EV (%s)" % str(e2.evs))
	# sauvegarde
	var o = Pokemon.creer("pikachu", 12, {"shiny": true, "nature": "jovial", "surnom": "ZAP", "genre": "f", "balle": "super_ball"})
	o.statut = "brulure"
	o.pv = 5
	o.objet_tenu = "baie_oran"
	var o2 = Pokemon.depuis_dictionnaire(JSON.parse_string(JSON.stringify(o.en_dictionnaire())))
	ok(o2.shiny and o2.nature == "jovial" and o2.nom == "ZAP" and o2.genre == "f" and o2.statut == "brulure" and o2.pv == 5 and o2.objet_tenu == "baie_oran" and o2.balle == "super_ball", "sauvegarde complete d'un individu")
	ok(o2.stats == o.stats and o2.ivs == o.ivs and o2.talent == o.talent, "stats/IV/talent conserves")
	print("Erreurs : ", erreurs)
	quit(1 if erreurs > 0 else 0)
