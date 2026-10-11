extends RefCounted
# Moteur de bataille : toute la logique d'un combat, SANS interface.
# L'ecran (combat.gd) donne les choix du joueur et rejoue la liste "evenements" produite par le moteur.
#
#   var b = Bataille.new()
#   b.demarrer(equipe_joueur, equipe_adverse, sauvage, "RIVAL")
#   b.tour({"t": "attaque", "id": "charge"})            # un tour complet (l'adversaire choisit tout seul)
#   var evs = b.vider_evenements()                        # messages, barres de PV, K.O., envois...
#   b.fin   # "" tant que ca continue, sinon "victoire" / "defaite" / "fuite" / "capture"
#
# Actions du joueur : {"t":"attaque","id"} {"t":"changer","index"} {"t":"fuite"} {"t":"objet","id","index"}
# Evenements : {"t":"msg","texte"} {"t":"maj","cote","etat":snapshot,"anime":bool} {"t":"secousse","cote"}
#              {"t":"ko","cote"} {"t":"envoi","cote","etat":snapshot} {"t":"pause","s"}
#
# Pour ajouter une mecanique : un talent -> TALENTS_*, une attaque speciale -> SPECIALES (cle = id_en de l'attaque),
# un statut -> _infliger / _fin_de_tour.

const Donnees := preload("res://scripts/donnees.gd")
const Pokemon := preload("res://scripts/pokemon.gd")

var rng := RandomNumberGenerator.new()
var equipe := {"j": [], "e": []}
var actif := {"j": null, "e": null}
var sauvage := true
var nom_dresseur := ""
var fin := ""
var evenements: Array = []
var vol := {}                       # Pokemon -> etats volatils (confusion, peur, vampigraine, piege...)
var participants: Array = []       # Pokemon du joueur ayant affronte l'adversaire actuel
var tentatives_fuite := 0
var a_evoluer: Array = []          # Pokemon du joueur qui peuvent evoluer apres le combat
var ecrans := {"j": {}, "e": {}}    # murs (reflet / mur lumiere) : nom -> tours restants
var tour_numero := 0
var capture = null                 # le Pokemon capture (quand fin == "capture")

const CRIT := [24, 8, 2, 1]        # 1 chance sur N selon le niveau de coup critique
const STATUTS_TXT := {
	"paralysie": "est paralyse ! Il aura du mal a attaquer", "brulure": "est brule", "poison": "est empoisonne",
	"poison_grave": "est gravement empoisonne", "sommeil": "s'endort", "gel": "est gele"}

func _init(graine := -1) -> void:
	if graine >= 0:
		rng.seed = graine
	else:
		rng.randomize()

# ---------- evenements ----------

func msg(t: String) -> void:
	evenements.append({"t": "msg", "texte": t})

func ev(t: String, d := {}) -> void:
	var e := {"t": t}
	e.merge(d)
	evenements.append(e)

func vider_evenements() -> Array:
	var r := evenements
	evenements = []
	return r

func etat(p) -> Dictionary:
	return {"nom": p.nom, "niveau": p.niveau, "pv": maxi(0, p.pv), "pv_max": p.stats["pv"], "statut": p.statut,
		"couleur": p.couleur(), "shiny": p.shiny, "genre": p.genre, "espece": p.espece_id, "exp": p.exp,
		"exp_min": p.exp_seuil(p.niveau), "exp_max": p.exp_seuil(p.niveau + 1)}

func maj(p, anime := true) -> void:
	ev("maj", {"cote": cote_de(p), "etat": etat(p), "anime": anime})

func cote_de(p) -> String:
	return "j" if equipe["j"].has(p) else "e"

func autre(c: String) -> String:
	return "e" if c == "j" else "j"

# nom affiche dans les messages
func nom(p) -> String:
	var n: String = p.nom.to_upper()
	if cote_de(p) == "e":
		return n + (" sauvage" if sauvage else " ennemi")
	return n

func v(p) -> Dictionary:
	if not vol.has(p):
		vol[p] = {}
	return vol[p]

# ---------- demarrage ----------

func demarrer(eq_j: Array, eq_e: Array, est_sauvage: bool, dresseur := "") -> void:
	equipe = {"j": eq_j, "e": eq_e}
	sauvage = est_sauvage
	nom_dresseur = dresseur
	fin = ""
	vol.clear()
	participants.clear()
	a_evoluer.clear()
	ecrans = {"j": {}, "e": {}}
	tentatives_fuite = 0
	tour_numero = 0
	for p in eq_j + eq_e:
		p.reinitialiser_stades()
	actif["j"] = premier_vivant("j")
	actif["e"] = eq_e[0]
	participants = [actif["j"]]
	if sauvage:
		msg("Un %s sauvage apparait !" % actif["e"].nom.to_upper())
	else:
		msg("%s veut se battre !" % nom_dresseur.to_upper())
		msg("%s envoie %s !" % [nom_dresseur.to_upper(), actif["e"].nom.to_upper()])
	ev("envoi", {"cote": "e", "etat": etat(actif["e"])})
	msg("Go ! %s !" % actif["j"].nom.to_upper())
	ev("envoi", {"cote": "j", "etat": etat(actif["j"])})
	_talent_entree(actif["j"])
	_talent_entree(actif["e"])

func premier_vivant(c: String):
	for p in equipe[c]:
		if not p.ko():
			return p
	return null

func vivants(c: String) -> Array:
	return equipe[c].filter(func(p): return not p.ko())

# ---------- IA de l'adversaire ----------

func action_ia() -> Dictionary:
	var p = actif["e"]
	var choix: Array = []
	for a in p.attaques:
		if a["pp"] > 0:
			choix.append(a["id"])
	if choix.is_empty():
		return {"t": "attaque", "id": "lutte"}
	if not sauvage:
		# dresseur : une fois sur deux, prend l'attaque qui fait le plus de degats estimes
		var meilleur := ""
		var m_deg := -1.0
		for id in choix:
			var a: Dictionary = Donnees.attaque(id)
			var d := float(a.get("puissance", 0)) * Donnees.efficacite(String(a["type"]), actif["j"].types) * (1.5 if p.types.has(a["type"]) else 1.0)
			if d > m_deg:
				m_deg = d
				meilleur = id
		if rng.randi_range(0, 1) == 0:
			return {"t": "attaque", "id": meilleur}
	return {"t": "attaque", "id": choix[rng.randi_range(0, choix.size() - 1)]}

# ---------- un tour ----------

func peut_fuir() -> bool:
	return sauvage

func vitesse(p) -> int:
	var s: int = p.stat("vit")
	if p.statut == "paralysie":
		s = int(s / 2)
	return s

func _priorite(c: String, a: Dictionary) -> int:
	match String(a["t"]):
		"changer": return 100
		"objet", "balle": return 90
		"fuite": return 80
		"attaque": return int(Donnees.attaque(String(a["id"])).get("priorite", 0))
	return 0

func tour(action_j: Dictionary, action_e := {}) -> void:
	if fin != "":
		return
	tour_numero += 1
	if action_e.is_empty():
		action_e = action_ia()
	var acteurs := {"j": actif["j"], "e": actif["e"]}
	var liste: Array = [["j", action_j], ["e", action_e]]
	liste.sort_custom(func(x, y):
		var px := _priorite(x[0], x[1])
		var py := _priorite(y[0], y[1])
		if px != py:
			return px > py
		var vx := vitesse(actif[x[0]])
		var vy := vitesse(actif[y[0]])
		if vx != vy:
			return vx > vy
		return false)
	# egalite de vitesse (meme priorite) : tirage au sort
	if _priorite("j", action_j) == _priorite("e", action_e) and vitesse(actif["j"]) == vitesse(actif["e"]) and rng.randi_range(0, 1) == 1:
		liste.reverse()
	for a in liste:
		if fin != "":
			return
		var c: String = a[0]
		var p = actif[c]
		if p == null or p.ko() or p != acteurs[c]:
			continue
		match String(a[1]["t"]):
			"changer": _changer(c, int(a[1]["index"]))
			"fuite": _fuite()
			"objet": _objet(c, a[1])
			"balle": _balle(c, a[1])
			"attaque": _attaque(c, String(a[1]["id"]))
		_verifier_fin()
	if fin == "":
		_fin_de_tour()
		_verifier_fin()

# ---------- changement de Pokemon ----------

func _changer(c: String, idx: int, force := false) -> void:
	var sortant = actif[c]
	var entrant = equipe[c][idx]
	if not force and sortant != null and not sortant.ko():
		msg(("Reviens, %s !" % sortant.nom.to_upper()) if c == "j" else ("%s rappelle %s !" % [nom_dresseur.to_upper(), sortant.nom.to_upper()]))
	if sortant != null:
		sortant.reinitialiser_stades()
		vol.erase(sortant)
	actif[c] = entrant
	vol.erase(entrant)
	if c == "j":
		participants = participants.filter(func(q): return not q.ko())
		if not participants.has(entrant):
			participants.append(entrant)
		msg("Go ! %s !" % entrant.nom.to_upper())
	else:
		msg("%s envoie %s !" % [nom_dresseur.to_upper(), entrant.nom.to_upper()])
		participants = participants.filter(func(q): return not q.ko())
		participants = [actif["j"]] if not actif["j"].ko() else []
	ev("envoi", {"cote": c, "etat": etat(entrant)})
	_talent_entree(entrant)

# apres un K.O. du Pokemon du joueur : l'ecran choisit le remplacant
func remplacer(idx: int) -> void:
	_changer("j", idx, true)

# ---------- fuite ----------

func _fuite() -> void:
	if not sauvage:
		msg("On ne s'enfuit pas d'un combat de dresseur !")
		return
	tentatives_fuite += 1
	var vj: int = actif["j"].stat("vit")
	var ve: int = maxi(1, actif["e"].stat("vit"))
	var f := int(vj * 128 / ve) + 30 * tentatives_fuite
	if f > 255 or rng.randi_range(0, 255) < f:
		msg("Tu prends la fuite !")
		fin = "fuite"
	else:
		msg("Impossible de fuir !")

# ---------- objets ----------

# soin pendant le combat : l'objet est decrit dans data/objets.json (soin_pv, soin_statut)
func _objet(c: String, a: Dictionary) -> void:
	var o: Dictionary = Donnees.objet(String(a["id"]))
	var cible = equipe[c][int(a.get("index", 0))]
	msg("%s utilise %s !" % ["Tu" if c == "j" else nom_dresseur.to_upper(), Donnees.nom_objet(String(a["id"]))])
	appliquer_objet(cible, o)

# renvoie vrai si l'objet a eu un effet
func appliquer_objet(cible, o: Dictionary) -> bool:
	var utile := false
	if o.has("soin_pv") and not cible.ko() and cible.pv < cible.stats["pv"]:
		var avant: int = cible.pv
		cible.pv = mini(cible.stats["pv"], cible.pv + int(o["soin_pv"]))
		msg("%s retrouve %d PV." % [cible.nom.to_upper(), cible.pv - avant])
		utile = true
	if o.has("soin_statut") and cible.statut != "" and (String(o["soin_statut"]) == "tous" or String(o["soin_statut"]) == cible.statut or (String(o["soin_statut"]) == "poison" and cible.statut == "poison_grave")):
		cible.statut = ""
		msg("%s est gueri !" % cible.nom.to_upper())
		utile = true
	if not utile:
		msg("Ca n'aurait aucun effet.")
	if cote_de(cible) == "j" or equipe["e"].has(cible):
		maj(cible)
	return utile

# ---------- capture ----------

# probabilite "a" de la formule de capture (>= 255 : capture assuree) ; mult = bonus de la balle
func facteur_capture(cible, mult: float) -> float:
	var pvm: float = cible.stats["pv"]
	var taux := float(Donnees.espece(cible.espece_id).get("taux_capture", 45))
	var statut := 1.0
	match cible.statut:
		"sommeil", "gel": statut = 2.5
		"paralysie", "poison", "poison_grave", "brulure": statut = 1.5
	return ((3.0 * pvm - 2.0 * cible.pv) * taux * mult) / (3.0 * pvm) * statut

# renvoie { "capture": bool, "secousses": 0..3 }
func tenter_capture(cible, mult: float) -> Dictionary:
	var a := facteur_capture(cible, mult)
	if mult >= 255.0 or a >= 255.0:
		return {"capture": true, "secousses": 3}
	var b: float = floor(65536.0 / pow(255.0 / a, 0.1875))
	var ok := 0
	for i in 4:
		if float(rng.randi_range(0, 65535)) < b:
			ok += 1
		else:
			break
	return {"capture": ok >= 4, "secousses": mini(ok, 3)}

func _balle(c: String, a: Dictionary) -> void:
	var o: Dictionary = Donnees.objet(String(a["id"]))
	var cible = actif["e"]
	msg("Tu lances une %s !" % Donnees.nom_objet(String(a["id"])))
	var r := tenter_capture(cible, float(o.get("balle", 1.0)))
	ev("balle", {"id": String(a["id"]), "secousses": r["secousses"], "capture": r["capture"]})
	if r["capture"]:
		msg("Ca y est ! %s est capture !" % cible.nom.to_upper())
		cible.balle = String(a["id"])
		capture = cible
		ev("ko", {"cote": "e"})
		_experience(cible)
		fin = "capture"
		_conclure()
		return
	match int(r["secousses"]):
		0: msg("Oh non ! Le POKEMON s'est libere !")
		1: msg("Mince ! Il etait presque capture !")
		2: msg("Aargh ! Presque !")
		_: msg("Zut ! Ca y etait presque !")
	ev("envoi", {"cote": "e", "etat": etat(cible)})

# ---------- attaques ----------

func _talent_id(p) -> String:
	return String(Donnees.talent(p.talent).get("id_anglais", ""))

func _multiplicateur_stade(s: int) -> float:
	return (3.0 + s) / 3.0 if s >= 0 else 3.0 / (3.0 - s)

func _peut_agir(c: String, p) -> bool:
	var vp := v(p)
	if p.statut == "sommeil":
		p.statut_tours -= 1
		if p.statut_tours <= 0:
			p.statut = ""
			msg("%s se reveille !" % nom(p))
			maj(p, false)
		else:
			msg("%s dort profondement." % nom(p))
			return false
	if p.statut == "gel":
		if rng.randi_range(1, 100) <= 20:
			p.statut = ""
			msg("%s n'est plus gele !" % nom(p))
			maj(p, false)
		else:
			msg("%s est gele, il ne peut pas bouger !" % nom(p))
			return false
	if vp.get("peur", false):
		vp["peur"] = false
		msg("%s a peur et ne peut pas attaquer !" % nom(p))
		return false
	if vp.get("confusion", 0) > 0:
		vp["confusion"] -= 1
		if vp["confusion"] <= 0:
			msg("%s n'est plus confus !" % nom(p))
		else:
			msg("%s est confus !" % nom(p))
			if rng.randi_range(1, 3) == 1:
				msg("Il se blesse dans sa confusion !")
				var d := _formule(p.niveau, 40, p.stat("atk"), p.stat("def"))
				d = maxi(1, int(d * rng.randi_range(85, 100) / 100.0))
				_degats(p, d)
				ev("secousse", {"cote": c})
				return false
	if p.statut == "paralysie" and rng.randi_range(1, 4) == 1:
		msg("%s est paralyse ! Il ne peut pas bouger !" % nom(p))
		return false
	if vp.get("attraction", false) and rng.randi_range(1, 2) == 1:
		msg("%s est amoureux, il ne peut pas attaquer !" % nom(p))
		return false
	return true

func _formule(niv: int, puiss: int, A: int, D: int) -> int:
	return int(floor(floor(floor(2.0 * niv / 5.0 + 2.0) * puiss * A / maxi(1, D)) / 50.0)) + 2

# inflige des degats bruts, met a jour la barre, renvoie les PV reellement perdus
func _degats(p, d: int) -> int:
	var perdu: int = mini(d, p.pv)
	p.pv -= perdu
	maj(p)
	if p.ko():
		pass
	return perdu

func _type_attaque(p, a: Dictionary) -> String:
	return String(a.get("type", "normal"))

func _attaque(c: String, id: String) -> void:
	var att = actif[c]
	var cib = actif[autre(c)]
	var a: Dictionary = Donnees.attaque(id)
	if a.is_empty():
		return
	if not _peut_agir(c, att):
		return
	for x in att.attaques:
		if x["id"] == id:
			x["pp"] = maxi(0, int(x["pp"]) - 1)
	msg("%s utilise %s !" % [nom(att), String(a.get("nom", id)).to_upper()])
	ev("pause", {"s": 0.4})
	var idn := String(a.get("id_en", ""))
	var e: Dictionary = a.get("effets", {})
	var categorie := String(a.get("categorie", "physique"))
	var cible_soi := String(a.get("cible", "")) in ["user", "user-or-ally", "users-field", "entire-field", "all-opponents", "opponents-field"]
	# --- precision
	if not cible_soi and int(a.get("precision", 0)) > 0:
		var prec := float(a["precision"]) * _multiplicateur_stade(clampi(int(att.stades.get("precision", 0)) - int(cib.stades.get("esquive", 0)), -6, 6))
		if rng.randf() * 100.0 >= prec:
			msg("L'attaque de %s rate !" % nom(att))
			return
	if SPECIALES.has(idn):
		if call(SPECIALES[idn], c, att, cib, a):
			return
	if categorie == "statut":
		_statut_move(c, att, cib, a)
		return
	# --- immunites de type / talent
	var eff := Donnees.efficacite(_type_attaque(att, a), cib.types)
	var tid := _talent_id(cib)
	if tid == "levitate" and String(a["type"]) == "sol":
		msg("%s est immunise grace a Levitation !" % nom(cib))
		return
	if (tid == "volt-absorb" and String(a["type"]) == "electrik") or (tid == "water-absorb" and String(a["type"]) == "eau"):
		var soin: int = mini(cib.stats["pv"] - cib.pv, int(cib.stats["pv"] / 4))
		cib.pv += soin
		maj(cib)
		msg("%s absorbe l'attaque et recupere des PV !" % nom(cib))
		return
	if eff == 0.0:
		msg("Ca n'affecte pas %s..." % nom(cib))
		return
	# --- nombre de coups
	var coups := 1
	if e.has("coups"):
		var mn := int(e["coups"][0])
		var mx := int(e["coups"][1])
		if mn == mx:
			coups = mn
		else:
			var t := rng.randi_range(0, 99)
			coups = 2 if t < 35 else (3 if t < 70 else (4 if t < 85 else 5))
	var total := 0
	var fait := 0
	var crit_vu := false
	for i in coups:
		if cib.ko():
			break
		var degats_fixes := _degats_fixes(idn, att, cib)
		var crit := false
		var d: int
		if degats_fixes >= 0:
			d = degats_fixes
		else:
			var palier := clampi(int(e.get("crit", 0)) + int(att.stades.get("crit", 0)), 0, 3)
			crit = rng.randi_range(1, CRIT[palier]) == 1
			d = calcul_degats(att, cib, a, crit, rng.randi_range(85, 100) / 100.0)
		# Fermete : survit a un coup qui l'aurait mis K.O. depuis les PV max
		if d >= cib.pv and cib.pv == cib.stats["pv"] and _talent_id(cib) == "sturdy":
			d = cib.pv - 1
			msg("%s tient bon grace a Fermete !" % nom(cib))
		var perdu := _degats(cib, d)
		total += perdu
		fait += 1
		ev("secousse", {"cote": cote_de(cib)})
		if crit:
			crit_vu = true
	if fait == 0:
		return
	ev("pause", {"s": 0.3})
	if coups > 1:
		msg("Touche %d fois !" % fait)
	if crit_vu:
		msg("Coup critique !")
	if eff > 1.0:
		msg("C'est super efficace !")
	elif eff < 1.0:
		msg("Ce n'est pas tres efficace...")
	# --- effets secondaires
	if e.has("drain") and total > 0:
		var gain: int = maxi(1, int(total * int(e["drain"]) / 100.0))
		gain = mini(gain, att.stats["pv"] - att.pv)
		if gain > 0:
			att.pv += gain
			maj(att)
			msg("%s absorbe l'energie de %s !" % [nom(att), nom(cib)])
	if not cib.ko():
		if e.has("statut") and rng.randi_range(1, 100) <= int(e.get("statut_chance", 100)):
			_infliger_move(cib, String(e["statut"]), att, false)
		if e.has("peur") and rng.randi_range(1, 100) <= int(e["peur"]) and cote_de(att) != cote_de(cib):
			v(cib)["peur"] = true
		if e.has("stades"):
			_stades_move(att, cib, e)
		_contact(att, cib, a)
	if e.has("recul") and total > 0 and not att.ko():
		var r := maxi(1, int(total * int(e["recul"]) / 100.0))
		_degats(att, r)
		msg("%s est blesse par le contrecoup !" % nom(att))
	if id == "lutte" and not att.ko():
		_degats(att, maxi(1, int(att.stats["pv"] / 4)))
		msg("%s est blesse par le contrecoup !" % nom(att))

func calcul_degats(att, cib, a: Dictionary, crit: bool, alea: float) -> int:
	var spec := String(a.get("categorie", "physique")) == "speciale"
	var st_a: String = "spa" if spec else "atk"
	var st_d: String = "spd" if spec else "def"
	var A: int = att.stat(st_a)
	var D: int = cib.stat(st_d)
	if crit:   # un coup critique ignore les baisses d'attaque et les hausses de defense
		A = att.stats[st_a] if att.stades[st_a] < 0 else A
		D = cib.stats[st_d] if cib.stades[st_d] > 0 else D
	var puiss := int(a.get("puissance", 0))
	# talents qui augmentent la puissance quand les PV sont bas
	var tid := _talent_id(att)
	if att.pv <= att.stats["pv"] / 3 and ((tid == "overgrow" and a["type"] == "plante") or (tid == "blaze" and a["type"] == "feu")
			or (tid == "torrent" and a["type"] == "eau") or (tid == "swarm" and a["type"] == "insecte")):
		puiss = int(puiss * 1.5)
	var d := _formule(att.niveau, puiss, A, D)
	if crit:
		d = int(floor(d * 1.5))
	d = int(floor(d * alea))
	if att.types.has(a["type"]):
		d = int(floor(d * 1.5))
	d = int(floor(d * Donnees.efficacite(String(a["type"]), cib.types)))
	if att.statut == "brulure" and not spec and tid != "guts":
		d = int(floor(d * 0.5))
	var mur: String = "mur_lumiere" if spec else "reflet"
	if ecrans[cote_de(cib)].has(mur) and not crit:
		d = int(floor(d * 0.5))
	return maxi(1, d)

# degats fixes de certaines attaques (-1 = calcul normal)
func _degats_fixes(idn: String, att, cib) -> int:
	match idn:
		"dragon-rage": return 40
		"sonic-boom": return 20
		"night-shade", "seismic-toss": return att.niveau
		"super-fang": return maxi(1, int(cib.pv / 2))
		"psywave": return maxi(1, int(att.niveau * (rng.randi_range(5, 15)) / 10.0))
		"guillotine", "horn-drill", "fissure": return cib.pv if rng.randi_range(1, 100) <= 30 else 0
	return -1

# ---------- attaques de statut ----------

func _statut_move(c: String, att, cib, a: Dictionary) -> void:
	var e: Dictionary = a.get("effets", {})
	var fait := false
	var sur_soi := String(a.get("cible", "")) in ["user", "user-or-ally"]
	var cible_ef = att if sur_soi else cib
	if e.has("statut"):
		fait = _infliger_move(cible_ef, String(e["statut"]), att, true) or fait
	if e.has("stades"):
		fait = _stades_move(att, cib, e) or fait
	if e.has("soin") and not att.ko():
		var gain: int = mini(att.stats["pv"] - att.pv, int(att.stats["pv"] * int(e["soin"]) / 100.0))
		if gain > 0:
			att.pv += gain
			maj(att)
			msg("%s recupere des PV !" % nom(att))
			fait = true
		else:
			msg("Les PV de %s sont deja au maximum !" % nom(att))
			return
	if not fait and not e.has("soin"):
		msg("Mais rien ne se passe...")

# applique un statut non volatil ou volatil. 'direct' = attaque de statut (message si ca echoue)
func _infliger_move(cible, s: String, source, direct: bool) -> bool:
	match s:
		"confusion":
			if v(cible).get("confusion", 0) > 0:
				if direct: msg("%s est deja confus !" % nom(cible))
				return false
			v(cible)["confusion"] = rng.randi_range(2, 5) + 1
			msg("%s est confus !" % nom(cible))
			return true
		"vampigraine":
			if cible.types.has("plante") or v(cible).get("vampigraine", false):
				if direct: msg("Ca n'affecte pas %s..." % nom(cible))
				return false
			v(cible)["vampigraine"] = true
			msg("%s est seme de graines !" % nom(cible))
			return true
		"attraction":
			if cible.genre == "" or source.genre == "" or cible.genre == source.genre or v(cible).get("attraction", false):
				if direct: msg("Mais cela echoue !")
				return false
			v(cible)["attraction"] = true
			msg("%s tombe amoureux !" % nom(cible))
			return true
		"paralysie", "brulure", "poison", "sommeil", "gel", "poison_grave":
			return infliger(cible, s, direct)
	return false

# statut non volatil (paralysie, brulure, poison, poison_grave, sommeil, gel)
func infliger(cible, s: String, direct := false) -> bool:
	if cible.statut != "" or cible.ko():
		if direct: msg("Mais cela echoue !")
		return false
	var immun := false
	match s:
		"brulure": immun = cible.types.has("feu")
		"poison", "poison_grave": immun = cible.types.has("poison") or cible.types.has("acier")
		"paralysie": immun = cible.types.has("electrik")
		"gel": immun = cible.types.has("glace")
	if immun:
		if direct: msg("Ca n'affecte pas %s..." % nom(cible))
		return false
	if v(cible).get("protege_statut", false):
		return false
	cible.statut = s
	cible.statut_tours = rng.randi_range(1, 3) if s == "sommeil" else (1 if s == "poison_grave" else 0)
	msg("%s %s !" % [nom(cible), STATUTS_TXT[s]])
	maj(cible)
	return true

func _stades_move(att, cib, e: Dictionary) -> bool:
	if rng.randi_range(1, 100) > int(e.get("stades_chance", 100)):
		return false
	var fait := false
	for m in e["stades"]:
		var cible = att if String(m["sur"]) == "soi" else cib
		fait = changer_stade(cible, String(m["stat"]), int(m["delta"])) or fait
	return fait

const NOMS_STATS := {"atk": "L'ATTAQUE", "def": "La DEFENSE", "spa": "L'ATT. SPE.", "spd": "La DEF. SPE.", "vit": "La VITESSE",
	"precision": "La PRECISION", "esquive": "L'ESQUIVE"}

func changer_stade(cible, s: String, n: int) -> bool:
	var avant: int = cible.stades[s]
	var apres := clampi(avant + n, -6, 6)
	if apres == avant:
		msg("%s de %s ne peut plus %s !" % [NOMS_STATS[s], nom(cible), "monter" if n > 0 else "baisser"])
		return false
	cible.stades[s] = apres
	var f := "monte" if n > 0 else "baisse"
	if absi(n) >= 2:
		f += " beaucoup"
	msg("%s de %s %s !" % [NOMS_STATS[s], nom(cible), f])
	return true

# ---------- talents ----------

func _talent_entree(p) -> void:
	if p == null or p.ko():
		return
	if _talent_id(p) == "intimidate":
		var adv = actif[autre(cote_de(p))]
		if adv != null and not adv.ko():
			msg("%s intimide %s !" % [nom(p), nom(adv)])
			changer_stade(adv, "atk", -1)

# talents declenches par un contact (les attaques physiques)
func _contact(att, cib, a: Dictionary) -> void:
	if String(a.get("categorie", "")) != "physique" or att.ko():
		return
	var tid := _talent_id(cib)
	if rng.randi_range(1, 100) > 30:
		return
	match tid:
		"static": infliger(att, "paralysie")
		"flame-body": infliger(att, "brulure")
		"poison-point": infliger(att, "poison")
		"effect-spore":
			infliger(att, ["sommeil", "paralysie", "poison"][rng.randi_range(0, 2)])

# ---------- attaques speciales (cle = id_en) : renvoient vrai si elles remplacent tout le reste ----------

const SPECIALES := {
	"reflect": "_sp_reflet", "light-screen": "_sp_mur_lumiere", "haze": "_sp_brume", "focus-energy": "_sp_puissance",
	"rest": "_sp_repos", "toxic": "_sp_toxik", "splash": "_sp_rien",
}

func _sp_reflet(c, att, cib, a) -> bool:
	ecrans[c]["reflet"] = 5
	msg("Un mur protege l'equipe de %s !" % nom(att))
	return true

func _sp_mur_lumiere(c, att, cib, a) -> bool:
	ecrans[c]["mur_lumiere"] = 5
	msg("Un mur de lumiere protege l'equipe de %s !" % nom(att))
	return true

func _sp_brume(c, att, cib, a) -> bool:
	att.reinitialiser_stades()
	cib.reinitialiser_stades()
	msg("Tous les changements de stats sont annules !")
	return true

func _sp_puissance(c, att, cib, a) -> bool:
	att.stades["crit"] = 2
	msg("%s se concentre !" % nom(att))
	return true

func _sp_repos(c, att, cib, a) -> bool:
	if att.pv >= att.stats["pv"] or att.statut == "sommeil":
		msg("Mais cela echoue !")
		return true
	att.statut = "sommeil"
	att.statut_tours = 3
	att.pv = att.stats["pv"]
	maj(att)
	msg("%s dort et recupere tous ses PV !" % nom(att))
	return true

func _sp_toxik(c, att, cib, a) -> bool:
	infliger(cib, "poison_grave", true)
	return true

func _sp_rien(c, att, cib, a) -> bool:
	msg("Mais rien ne se passe...")
	return true

# ---------- fin de tour ----------

func _fin_de_tour() -> void:
	for c in ["j", "e"]:
		var p = actif[c]
		if p == null or p.ko():
			continue
		v(p)["peur"] = false
		match p.statut:
			"brulure":
				msg("%s souffre de sa brulure !" % nom(p))
				_degats(p, maxi(1, int(p.stats["pv"] / 16)))
			"poison":
				msg("%s souffre du poison !" % nom(p))
				_degats(p, maxi(1, int(p.stats["pv"] / 8)))
			"poison_grave":
				msg("%s souffre du poison !" % nom(p))
				_degats(p, maxi(1, int(p.stats["pv"] * mini(p.statut_tours, 15) / 16.0)))
				p.statut_tours += 1
		if not p.ko() and v(p).get("vampigraine", false):
			var adv = actif[autre(c)]
			var d: int = maxi(1, int(p.stats["pv"] / 8))
			d = _degats(p, d)
			msg("Vampigraine pompe l'energie de %s !" % nom(p))
			if adv != null and not adv.ko():
				adv.pv = mini(adv.stats["pv"], adv.pv + d)
				maj(adv)
		if p.ko():
			continue
	for c in ["j", "e"]:
		for k in ecrans[c].keys():
			ecrans[c][k] -= 1
			if ecrans[c][k] <= 0:
				ecrans[c].erase(k)
				msg("Le mur de l'equipe %s disparait." % ("allie" if c == "j" else "adverse"))

# ---------- K.O., experience, fin ----------

# traite les K.O. : experience, remplacement, victoire / defaite
func _verifier_fin() -> void:
	if fin != "":
		return
	var e = actif["e"]
	if e != null and e.ko() and not v(e).get("ko_traite", false):
		v(e)["ko_traite"] = true
		ev("ko", {"cote": "e"})
		msg("%s est K.O. !" % nom(e))
		_experience(e)
		var suivant = premier_vivant("e")
		if suivant == null:
			fin = "victoire"
			if not sauvage:
				msg("%s a ete battu !" % nom_dresseur.to_upper())
			_conclure()
			return
		_changer("e", equipe["e"].find(suivant), true)
	var j = actif["j"]
	if j != null and j.ko() and not v(j).get("ko_traite", false):
		v(j)["ko_traite"] = true
		ev("ko", {"cote": "j"})
		msg("%s est K.O. !" % nom(j))
		if premier_vivant("j") == null:
			fin = "defaite"
			msg("Tu n'as plus de POKEMON en etat de se battre !")
			_conclure()

# vrai quand le Pokemon du joueur est K.O. mais qu'il en reste : l'ecran doit appeler remplacer(index)
func remplacement_requis() -> bool:
	return fin == "" and actif["j"].ko() and premier_vivant("j") != null

func _experience(vaincu) -> void:
	var esp: Dictionary = Donnees.espece(vaincu.espece_id)
	var base := float(esp.get("exp_base", 50))
	var gagnants: Array = participants.filter(func(q): return not q.ko())
	if gagnants.is_empty():
		return
	for q in gagnants:
		var L: float = vaincu.niveau
		var Lp: float = q.niveau
		var g := int(floor(floor(base * L / (5.0 * gagnants.size())) * pow((2.0 * L + 10.0) / (L + Lp + 10.0), 2.5)) + 1)
		if not sauvage:
			g = int(g * 1.5)
		if q.niveau >= int(Donnees.regle("niveau_max", 100)):
			continue
		msg("%s gagne %d points d'EXP !" % [q.nom.to_upper(), g])
		q.gagner_ev(esp.get("ev", {}))
		var msgs: Array = q.gagner_exp(g)
		if cote_de(q) == "j":
			if actif["j"] == q:
				maj(q, true)
			for m in msgs:
				msg(String(m))
	participants = [actif["j"]] if not actif["j"].ko() else []

func _conclure() -> void:
	for p in equipe["j"]:
		p.reinitialiser_stades()
		if not p.ko() and p.evolution_possible({}) != "":
			a_evoluer.append(p)
	if fin == "victoire" and not sauvage:
		pass
