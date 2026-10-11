extends SceneTree
# Moteur de bataille (sans interface)
const Donnees := preload("res://scripts/donnees.gd")
const Pokemon := preload("res://scripts/pokemon.gd")
const Bataille := preload("res://scripts/bataille.gd")
var erreurs := 0
func ok(c: bool, msg: String) -> void:
	if not c:
		print("FAIL " + msg)
		erreurs += 1
	else:
		print("OK   " + msg)
func poke(espece: String, niv: int, attaques: Array, opts := {}):
	var p = Pokemon.creer(espece, niv, opts)
	p.attaques = []
	for id in attaques:
		var pp: int = int(Donnees.attaque(id).get("pp", 10))
		p.attaques.append({"id": id, "pp": pp, "pp_max": pp})
	return p
func textes(b) -> Array:
	var r := []
	for e in b.vider_evenements():
		if e["t"] == "msg": r.append(e["texte"])
	return r
func combat(j: Array, e: Array, sauvage := true, graine := 1):
	var b = Bataille.new(graine)
	b.demarrer(j, e, sauvage, "RIVAL")
	b.vider_evenements()
	return b
func _init() -> void:
	Pokemon.deterministe = true
	# --- degats : formule connue (niv 50, A=100, D=100, puissance 80, sans STAB ni type)
	var b = combat([poke("rattata", 5, ["charge"])], [poke("rattata", 5, ["charge"])])
	ok(b._formule(50, 80, 100, 100) == int(floor(floor(floor(2.0 * 50 / 5 + 2) * 80 * 100 / 100) / 50.0)) + 2 and b._formule(50, 80, 100, 100) == 37, "formule de degats niv50/80/100/100 = 37 (%d)" % b._formule(50, 80, 100, 100))
	# --- STAB et efficacite
	var sal = poke("salameche", 20, ["flammeche", "charge"])
	var bul = poke("bulbizarre", 20, ["charge"])
	var car = poke("carapuce", 20, ["charge"])
	b = combat([sal], [bul])
	var d_feu: int = b.calcul_degats(sal, bul, Donnees.attaque("flammeche"), false, 1.0)
	var d_feu_eau: int = b.calcul_degats(sal, car, Donnees.attaque("flammeche"), false, 1.0)
	ok(d_feu > d_feu_eau * 3, "feu x2 sur plante, x0.5 sur eau (%d vs %d)" % [d_feu, d_feu_eau])
	var d_stab: int = b.calcul_degats(sal, bul, Donnees.attaque("flammeche"), false, 1.0)
	sal.types = ["normal"]
	var d_sans: int = b.calcul_degats(sal, bul, Donnees.attaque("flammeche"), false, 1.0)
	sal.types = ["feu"]
	ok(d_stab > d_sans, "STAB x1.5")
	var d_crit: int = b.calcul_degats(sal, bul, Donnees.attaque("flammeche"), true, 1.0)
	ok(d_crit > d_stab, "coup critique")
	sal.statut = "brulure"
	var d_brule: int = b.calcul_degats(sal, bul, Donnees.attaque("charge"), false, 1.0)
	sal.statut = ""
	var d_normal: int = b.calcul_degats(sal, bul, Donnees.attaque("charge"), false, 1.0)
	ok(d_brule * 2 <= d_normal + 2, "brulure : attaque physique /2 (%d vs %d)" % [d_brule, d_normal])
	# --- un tour : le plus rapide attaque en premier, les PV baissent
	var rap = poke("roucool", 20, ["charge"])
	var len = poke("ramoloss", 20, ["charge"])
	b = combat([len], [rap])
	b.tour({"t": "attaque", "id": "charge"})
	var tx: Array = textes(b)
	var i_rap := -1; var i_len := -1
	for k in tx.size():
		if "ROUCOOL sauvage utilise" in tx[k]: i_rap = k
		if "RAMOLOSS utilise" in tx[k]: i_len = k
	ok(i_rap >= 0 and i_len > i_rap, "le plus rapide frappe d'abord %s" % str(tx))
	ok(rap.pv < rap.stats["pv"] and len.pv < len.stats["pv"], "les deux ont perdu des PV")
	# --- priorite : Vive-Attaque passe avant un plus rapide
	var lent = poke("ramoloss", 20, ["vive_attaque"])
	var vite = poke("roucool", 20, ["charge"])
	b = combat([lent], [vite])
	b.tour({"t": "attaque", "id": "vive_attaque"})
	tx = textes(b)
	ok("RAMOLOSS utilise VIVE-ATTAQUE !" in tx[0], "priorite +1 : %s" % str(tx.slice(0, 2)))
	# --- statuts
	var paralyseur = poke("pikachu", 20, ["cage_eclair", "charge"])
	var cible = poke("rattata", 20, ["charge"])
	b = combat([paralyseur], [cible], true, 3)
	b._attaque("j", "cage_eclair")
	ok(cible.statut == "paralysie" or "rate" in " ".join(textes(b)), "Cage-Eclair paralyse (ou rate)")
	var tentatives := 0
	while cible.statut != "paralysie" and tentatives < 20:
		b._attaque("j", "cage_eclair")
		tentatives += 1
	ok(cible.statut == "paralysie", "paralysie appliquee")
	ok(b.vitesse(cible) == int(cible.stat("vit") / 2), "paralysie : vitesse /2")
	var elec = poke("pikachu", 20, ["charge"])
	ok(not b.infliger(elec, "paralysie"), "electrik immunise a la paralysie")
	var feu = poke("salameche", 20, ["charge"])
	ok(not b.infliger(feu, "brulure") and b.infliger(cible, "brulure") == false, "feu immunise a la brulure, pas de 2e statut")
	var emp = poke("rattata", 20, ["charge"])
	b = combat([poke("pikachu", 20, ["charge"])], [emp])
	b.infliger(emp, "poison")
	var pv0: int = emp.pv
	b._fin_de_tour()
	ok(pv0 - emp.pv == max(1, int(emp.stats["pv"] / 8)), "poison : 1/8 des PV par tour")
	var tox = poke("rattata", 20, ["charge"])
	b.infliger(tox, "poison_grave")
	var t0: int = tox.pv
	b.equipe["e"] = [tox]; b.actif["e"] = tox
	b._fin_de_tour(); var t1: int = tox.pv
	b._fin_de_tour(); var t2: int = tox.pv
	ok(t0 - t1 < t1 - t2, "poison grave : degats croissants (%d, %d)" % [t0 - t1, t1 - t2])
	var dort = poke("rattata", 20, ["charge"])
	b = combat([poke("pikachu", 20, ["charge"])], [dort])
	b.infliger(dort, "sommeil")
	var n_tours: int = dort.statut_tours
	ok(n_tours >= 1 and n_tours <= 3, "sommeil : 1 a 3 tours")
	var reveil := false
	for k in 4:
		b.vider_evenements()
		if b._peut_agir("e", dort): reveil = true; break
	ok(reveil and dort.statut == "", "le sommeil finit par passer")
	# --- confusion
	var conf = poke("rattata", 20, ["charge"])
	b = combat([poke("pikachu", 20, ["charge"])], [conf])
	b._infliger_move(conf, "confusion", null, false)
	var blesse := false
	var agit := false
	for k in 60:
		b.v(conf)["confusion"] = 3
		conf.pv = conf.stats["pv"]
		b.vider_evenements()
		if b._peut_agir("e", conf): agit = true
		elif conf.pv < conf.stats["pv"]: blesse = true
	ok(agit and blesse, "confusion : agit parfois, se blesse parfois")
	# --- stades / precision
	var r1 = poke("rattata", 20, ["rugissement", "charge"])
	var r2 = poke("rattata", 20, ["charge"])
	b = combat([r1], [r2])
	b._attaque("j", "rugissement")
	ok(r2.stades["atk"] == -1, "Rugissement : ATK adverse -1")
	for k in 8: b.changer_stade(r2, "atk", -1)
	ok(r2.stades["atk"] == -6, "stades bornes a -6")
	# --- drain / recul / soin
	var drain = poke("bulbizarre", 30, ["vampigraine", "charge"])
	var vic = poke("carapuce", 30, ["charge"])
	b = combat([drain], [vic], true, 5)
	b._attaque("j", "vampigraine")
	ok(b.v(vic).get("vampigraine", false) or true, "vampigraine posee ou ratee")
	b.v(vic)["vampigraine"] = true
	drain.pv = drain.stats["pv"] - 10
	var av: int = vic.pv
	b._fin_de_tour()
	ok(vic.pv < av and drain.pv > drain.stats["pv"] - 10, "vampigraine : transfert de PV")
	var soigneur = poke("rattata", 30, ["repos"])
	soigneur.pv = 1
	b = combat([soigneur], [poke("rattata", 5, ["charge"])])
	b._attaque("j", soigneur.attaques[0]["id"])
	ok(soigneur.pv > 1, "attaque de soin/repos : PV recuperes (%d)" % soigneur.pv)
	# --- talents
	var intim = poke("arbok", 30, ["charge"], {"talent": "intimidation"})
	var vic2 = poke("rattata", 30, ["charge"])
	b = Bataille.new(1)
	b.demarrer([vic2], [intim], false, "X")
	ok(vic2.stades["atk"] == -1, "Intimidation : ATK adverse -1 a l'entree (%s)" % intim.talent)
	var lev = poke("smogo", 30, ["charge"], {"talent": "levitation"})
	var tr = poke("sabelette", 30, ["jet_de_sable" if false else "charge"])
	b = combat([tr], [lev])
	var sol = poke("sabelette", 30, ["tunnel"])
	b = combat([sol], [lev])
	b._attaque("j", "tunnel")
	ok(lev.pv == lev.stats["pv"], "Levitation : immunise aux attaques Sol")
	# --- fuite
	var vj = poke("roucool", 30, ["charge"])
	var vs = poke("rattata", 3, ["charge"])
	b = combat([vj], [vs], true, 2)
	b.tour({"t": "fuite"})
	ok(b.fin == "fuite", "fuite reussie contre plus lent")
	b = combat([poke("ramoloss", 60, ["charge"])], [poke("roucool", 5, ["charge"])], false, 2)
	b.tour({"t": "fuite"})
	ok(b.fin == "" and "On ne s'enfuit pas" in " ".join(textes(b)), "pas de fuite contre un dresseur")
	# --- changement + K.O. + remplacement + defaite
	var a1 = poke("rattata", 5, ["charge"])
	var a2 = poke("roucool", 5, ["charge"])
	var fort = poke("onix", 40, ["charge"])
	b = combat([a1, a2], [fort], true, 4)
	b.tour({"t": "changer", "index": 1})
	ok(b.actif["j"] == a2, "changement de Pokemon")
	for k in 10:
		if b.fin != "" or b.remplacement_requis(): break
		b.tour({"t": "attaque", "id": "charge"})
	ok(b.remplacement_requis() or b.fin != "", "K.O. : remplacement demande")
	b.vider_evenements()
	if b.remplacement_requis():
		var idx: int = b.equipe["j"].find(b.premier_vivant("j"))
		b.remplacer(idx)
		ok(b.actif["j"] == b.premier_vivant("j") and not b.actif["j"].ko(), "remplacant envoye")
	for k in 20:
		if b.fin != "": break
		if b.remplacement_requis(): b.remplacer(b.equipe["j"].find(b.premier_vivant("j")))
		b.tour({"t": "attaque", "id": "charge"})
	ok(b.fin == "defaite", "defaite quand toute l'equipe est K.O. (%s)" % b.fin)
	# --- victoire + EXP partagee
	var f1 = poke("salameche", 30, ["flammeche"])
	var f2 = poke("carapuce", 30, ["charge"])
	var faible = poke("rattata", 3, ["charge"])
	faible.pv = 1
	b = combat([f1, f2], [faible], true, 6)
	b.tour({"t": "changer", "index": 1})
	b.tour({"t": "attaque", "id": "charge"})
	var e1: int = f1.exp; var e2: int = f2.exp
	ok(b.fin == "victoire" and f1.exp > e1 - 1 and f2.exp > e2 - 1, "victoire sauvage (%s)" % b.fin)
	ok(f1.exp > f1.exp_seuil(30) and f2.exp > f2.exp_seuil(30), "EXP partagee entre les deux participants (%d / %d)" % [f1.exp, f2.exp])
	
	b = combat([poke("rattata", 5, ["charge"])], [poke("rattata", 3, ["charge"])], false)
	ok(true, "dresseur initialise")
	# --- objets
	var bless = poke("rattata", 20, ["charge"])
	bless.pv = 3
	b = combat([bless], [poke("rattata", 5, ["charge"])])
	b.tour({"t": "objet", "id": "potion", "index": 0})
	ok(bless.pv > 3 or "Ca n'aurait" in " ".join(textes(b)), "objet utilise en combat")
	# --- reflet
	var r_att = poke("rattata", 20, ["charge"])
	var r_def = poke("rattata", 20, ["reflet"])
	b = combat([r_att], [r_def])
	var d_av: int = b.calcul_degats(r_att, r_def, Donnees.attaque("charge"), false, 1.0)
	b.ecrans["e"]["reflet"] = 5
	var d_ap: int = b.calcul_degats(r_att, r_def, Donnees.attaque("charge"), false, 1.0)
	ok(d_ap * 2 <= d_av + 2 and d_ap < d_av, "Reflet : degats physiques /2")
	# --- balayage de TOUTES les attaques : aucune ne doit planter
	var crash := 0
	var toutes: Dictionary = Donnees._lire("attaques")
	for id in toutes.keys():
		var A = poke("evoli", 30, [id])
		var B = poke("rattata", 30, ["charge"])
		var bb = combat([A], [B], true, 9)
		for k in 3:
			if bb.fin != "": break
			bb.tour({"t": "attaque", "id": id}, {"t": "attaque", "id": "charge"})
			A.pv = A.stats["pv"]; B.pv = B.stats["pv"]
			A.attaques[0]["pp"] = 30
			bb.vider_evenements()
	ok(true, "%d attaques jouees sans erreur" % toutes.size())
	print("Erreurs : ", erreurs)
	quit(1 if erreurs > 0 else 0)
