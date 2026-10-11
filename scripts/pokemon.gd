extends RefCounted
# Un Pokemon (equipe, adversaire, PC) : espece, niveau, IV/EV, nature, talent, genre, shiny, statut, attaques, experience.
# Formules modernes (generation 6+). Tout ce qui est "regle" est dans data/*.json (pokemon, attaques, natures, talents, courbes, regles).

const Donnees := preload("res://scripts/donnees.gd")
const STATS := ["pv", "atk", "def", "spa", "spd", "vit"]
const STATS_COMBAT := ["atk", "def", "spa", "spd", "vit", "precision", "esquive"]

# mode des tests : IV=15, nature neutre, pas de shiny, premier talent -> stats reproductibles
static var deterministe := false
static var rng := RandomNumberGenerator.new()

var espece_id := ""
var surnom := ""
var niveau := 1
var types: Array = []
var stats := {}                 # pv, atk, def, spa, spd, vit (stats "de base du niveau", sans modificateurs de combat)
var ivs := {}
var evs := {}
var nature := "hardi"
var talent := ""
var genre := ""                 # "m", "f" ou "" (asexue)
var shiny := false
var statut := ""                # "", paralysie, brulure, gel, poison, poison_grave, sommeil
var statut_tours := 0           # tours de sommeil restants / compteur de poison grave
var pv := 1
var attaques: Array = []        # [{ "id", "pp", "pp_max" }]
var exp := 0
var bonheur := 70
var objet_tenu := ""
var balle := ""                 # balle utilisee pour la capture
var dresseur_origine := ""
var niveau_rencontre := 1
var attaques_en_attente: Array = []   # attaques que le Pokemon voudrait apprendre mais qui attendent une place (UI : etape combat)
var stades := {}                # modificateurs de combat (-6 a +6)
var nom: String:                # nom affiche : surnom ou nom de l'espece
	get: return surnom if surnom != "" else nom_espece()

func nom_espece() -> String:
	return String(Donnees.espece(espece_id).get("nom", espece_id))

# opts (facultatif) : "shiny", "nature", "talent", "genre", "ivs" {stat: n}, "evs", "surnom", "balle", "dresseur"
static func creer(id: String, niv: int, opts := {}):
	var p = load("res://scripts/pokemon.gd").new()
	var e: Dictionary = Donnees.espece(id)
	p.espece_id = id
	p.types = e.get("types", [])
	p.niveau = niv
	p.niveau_rencontre = niv
	p.bonheur = int(e.get("bonheur_base", 70))
	p.surnom = String(opts.get("surnom", ""))
	p.balle = String(opts.get("balle", ""))
	p.dresseur_origine = String(opts.get("dresseur", ""))
	# individu
	var iv_max: int = int(Donnees.regle("iv_max", 31))
	for s in STATS:
		p.ivs[s] = 15 if deterministe else rng.randi_range(0, iv_max)
		p.evs[s] = 0
	for s in opts.get("ivs", {}):
		p.ivs[s] = clampi(int(opts["ivs"][s]), 0, iv_max)
	for s in opts.get("evs", {}):
		p.evs[s] = int(opts["evs"][s])
	if opts.has("nature"):
		p.nature = String(opts["nature"])
	elif not deterministe:
		var ns := Donnees.toutes_les_natures()
		p.nature = String(ns[rng.randi_range(0, ns.size() - 1)])
	var ts: Array = e.get("talents", [])
	if opts.has("talent"):
		p.talent = String(opts["talent"])
	elif not ts.is_empty():
		p.talent = String(ts[0] if deterministe else ts[rng.randi_range(0, ts.size() - 1)])
	var pf := float(e.get("pct_femelle", -1))
	if opts.has("genre"):
		p.genre = String(opts["genre"])
	elif pf >= 0.0:
		p.genre = "f" if (not deterministe and rng.randf() * 100.0 < pf) else "m"
	if opts.has("shiny"):
		p.shiny = bool(opts["shiny"])
	elif not deterministe:
		p.shiny = rng.randi_range(0, maxi(1, int(Donnees.regle("proba_shiny", 4096))) - 1) == 0
	p.exp = p.exp_seuil(niv)
	p._calculer_stats()
	p.pv = p.stats["pv"]
	p._apprendre_initial()
	p.reinitialiser_stades()
	return p

# ---------- experience ----------

# EXP totale pour atteindre le niveau n avec une courbe donnee (par defaut "moyenne_lente")
static func exp_pour_niveau(n: int, courbe := "moyenne_lente") -> int:
	if n <= 1:
		return 0
	var t: Array = Donnees.courbe(courbe)
	return int(t[clampi(n, 1, t.size()) - 1])

func exp_seuil(n: int) -> int:
	return exp_pour_niveau(n, String(Donnees.espece(espece_id).get("courbe", "moyenne_lente")))

# ---------- statistiques ----------

func couleur() -> String:
	var e: Dictionary = Donnees.espece(espece_id)
	if shiny and e.has("couleur_shiny"):
		return String(e["couleur_shiny"])
	return String(e.get("couleur", "#888888"))

func _calculer_stats() -> void:
	var b: Dictionary = Donnees.espece(espece_id).get("base", {})
	var nat: Dictionary = Donnees.nature(nature)
	var pv_pleins: int = int(stats.get("pv", 0))
	for s in STATS:
		var base := int(b.get(s, 1))
		var core := int(floor(float((2 * base + int(ivs.get(s, 0)) + int(floor(int(evs.get(s, 0)) / 4.0))) * niveau) / 100.0))
		if s == "pv":
			stats[s] = core + niveau + 10
		else:
			var m := 1.0
			if nat.get("plus", "") == s:
				m = 1.1
			if nat.get("moins", "") == s:
				m = 0.9
			stats[s] = int(floor((core + 5) * m))

func _apprendre_initial() -> void:
	attaques.clear()
	var appr: Array = []
	for e in Donnees.espece(espece_id).get("attaques_niveau", []):
		if int(e[0]) <= niveau and not appr.has(String(e[1])):
			appr.append(String(e[1]))
	for id in appr.slice(maxi(0, appr.size() - int(Donnees.regle("attaques_max", 4)))):
		_ajouter_attaque(id)

func _ajouter_attaque(id: String) -> void:
	var a: Dictionary = Donnees.attaque(id)
	if a.is_empty():
		return
	attaques.append({"id": id, "pp": int(a.get("pp", 10)), "pp_max": int(a.get("pp", 10))})

func connait(id: String) -> bool:
	for a in attaques:
		if a["id"] == id:
			return true
	return false

func reinitialiser_stades() -> void:
	stades = {}
	for s in STATS_COMBAT:
		stades[s] = 0
	stades["crit"] = 0

func ko() -> bool:
	return pv <= 0

func soigner() -> void:
	pv = stats["pv"]
	statut = ""
	statut_tours = 0
	for a in attaques:
		a["pp"] = a["pp_max"]

# valeur d'une stat en tenant compte des modificateurs de combat (precision/esquive : voir combat)
func stat(nom_stat: String) -> int:
	var s: int = stats[nom_stat]
	var st: int = stades.get(nom_stat, 0)
	var m := (2.0 + st) / 2.0 if st >= 0 else 2.0 / (2.0 - st)
	return maxi(1, int(floor(s * m)))

# ---------- progression ----------

# gagne de l'experience ; renvoie les messages (montee de niveau, nouvelle attaque...).
# Les attaques sans place libre sont mises dans attaques_en_attente.
func gagner_exp(quantite: int) -> Array:
	var msgs: Array = []
	exp += quantite
	var niv_max: int = int(Donnees.regle("niveau_max", 100))
	while niveau < niv_max and exp >= exp_seuil(niveau + 1):
		var anciens_pv: int = stats["pv"]
		niveau += 1
		_calculer_stats()
		pv += stats["pv"] - anciens_pv
		msgs.append("%s monte au niveau %d !" % [nom, niveau])
		for e in Donnees.espece(espece_id).get("attaques_niveau", []):
			if int(e[0]) == niveau and not connait(String(e[1])):
				var id := String(e[1])
				if attaques.size() < int(Donnees.regle("attaques_max", 4)):
					_ajouter_attaque(id)
					msgs.append("%s apprend %s !" % [nom, Donnees.attaque(id).get("nom", id)])
				elif not attaques_en_attente.has(id):
					attaques_en_attente.append(id)
	return msgs

# gagne des EV (rendement de l'espece vaincue), en respectant les plafonds
func gagner_ev(rendement: Dictionary) -> void:
	var total := 0
	for s in STATS:
		total += int(evs.get(s, 0))
	var max_stat: int = int(Donnees.regle("ev_max_stat", 252))
	var max_total: int = int(Donnees.regle("ev_max_total", 510))
	for s in rendement:
		var ajout := mini(int(rendement[s]), mini(max_stat - int(evs.get(s, 0)), max_total - total))
		if ajout > 0:
			evs[s] = int(evs.get(s, 0)) + ajout
			total += ajout
	var ancien: int = stats["pv"]
	_calculer_stats()
	pv = mini(stats["pv"], pv + maxi(0, stats["pv"] - ancien))

# espece vers laquelle ce Pokemon evolue maintenant ("" si aucune).
# ctx : { "objet": id (pierre utilisee), "echange": bool, "moment": "jour"/"nuit" }
func evolution_possible(ctx := {}) -> String:
	for e in Donnees.espece(espece_id).get("evolutions", []):
		if e.has("niveau") and niveau < int(e["niveau"]):
			continue
		if e.has("bonheur") and bonheur < int(e["bonheur"]):
			continue
		if e.has("moment") and String(ctx.get("moment", "")) != String(e["moment"]):
			continue
		if e.has("genre") and genre != String(e["genre"]):
			continue
		if e.has("attaque_connue") and not connait(String(e["attaque_connue"])):
			continue
		if e.has("echange") and not bool(ctx.get("echange", false)):
			continue
		if e.has("objet") and String(ctx.get("objet", "")) != String(e["objet"]):
			continue
		if not (e.has("niveau") or e.has("bonheur") or e.has("echange") or e.has("objet")):
			continue   # condition non geree (pas d'evolution automatique)
		return String(e["vers"])
	return ""

func evoluer(vers: String) -> void:
	var anciens: int = stats["pv"]
	espece_id = vers
	types = Donnees.espece(vers).get("types", [])
	var ts: Array = Donnees.espece(vers).get("talents", [])
	if not ts.has(talent) and not ts.is_empty():
		talent = String(ts[0])
	_calculer_stats()
	pv = mini(stats["pv"], pv + stats["pv"] - anciens)

# ---------- sauvegarde ----------

func en_dictionnaire() -> Dictionary:
	return {"espece": espece_id, "surnom": surnom, "niveau": niveau, "exp": exp, "pv": pv, "attaques": attaques.duplicate(true),
		"ivs": ivs.duplicate(), "evs": evs.duplicate(), "nature": nature, "talent": talent, "genre": genre, "shiny": shiny,
		"statut": statut, "statut_tours": statut_tours, "bonheur": bonheur, "objet": objet_tenu, "balle": balle,
		"dresseur": dresseur_origine, "niveau_rencontre": niveau_rencontre, "attente": attaques_en_attente.duplicate()}

static func depuis_dictionnaire(d: Dictionary):
	var p = creer(String(d["espece"]), int(d["niveau"]), {"surnom": String(d.get("surnom", ""))})
	# anciennes sauvegardes : pas d'individu enregistre -> on garde celui tire au hasard
	if d.has("ivs"):
		for s in STATS:
			p.ivs[s] = int(d["ivs"].get(s, 0))
			p.evs[s] = int(d.get("evs", {}).get(s, 0))
	p.nature = String(d.get("nature", p.nature))
	p.talent = String(d.get("talent", p.talent))
	p.genre = String(d.get("genre", p.genre))
	p.shiny = bool(d.get("shiny", false))
	p.statut = String(d.get("statut", ""))
	p.statut_tours = int(d.get("statut_tours", 0))
	p.bonheur = int(d.get("bonheur", p.bonheur))
	p.objet_tenu = String(d.get("objet", ""))
	p.balle = String(d.get("balle", ""))
	p.dresseur_origine = String(d.get("dresseur", ""))
	p.niveau_rencontre = int(d.get("niveau_rencontre", p.niveau))
	p.attaques_en_attente = Array(d.get("attente", []))
	p._calculer_stats()
	p.exp = int(d.get("exp", p.exp))
	p.pv = clampi(int(d.get("pv", p.stats["pv"])), 0, p.stats["pv"])
	var att: Array = []
	for a in d.get("attaques", []):
		if not Donnees.attaque(String(a["id"])).is_empty():
			att.append({"id": String(a["id"]), "pp": int(a["pp"]), "pp_max": int(a["pp_max"])})
	if not att.is_empty():
		p.attaques = att
	return p
