extends RefCounted
# Un Pokemon de l'equipe (ou de l'adversaire) : espece, niveau, stats, PV, attaques, experience.
# Formules de la 1re generation (stat "Special" unique).

const Donnees := preload("res://scripts/donnees.gd")
const DV := 8   # valeur de "talent" fixe pour tous les Pokemon

var espece_id := ""
var nom := ""
var niveau := 1
var types: Array = []
var stats := {}                 # pv, atk, def, vit, spe
var pv := 1
var attaques: Array = []        # [{ "id", "pp", "pp_max" }]
var exp := 0
var stades := {}                # modificateurs de combat : atk, def, vit, spe (-6 a +6)

static func creer(id: String, niv: int):
	var p = load("res://scripts/pokemon.gd").new()
	var e: Dictionary = Donnees.espece(id)
	p.espece_id = id
	p.nom = String(e.get("nom", id))
	p.types = e.get("types", [])
	p.niveau = niv
	p.exp = exp_pour_niveau(niv)
	p._calculer_stats()
	p.pv = p.stats["pv"]
	p._apprendre_initial()
	p.reinitialiser_stades()
	return p

# courbe "moyenne lente"
static func exp_pour_niveau(n: int) -> int:
	if n <= 1:
		return 0
	return maxi(0, int(floor(1.2 * pow(n, 3) - 15.0 * pow(n, 2) + 100.0 * n - 140.0)))

func _calculer_stats() -> void:
	var b: Dictionary = Donnees.espece(espece_id).get("base", {})
	stats["pv"] = int(floor(float((int(b.get("pv", 1)) + DV) * 2 * niveau) / 100.0)) + niveau + 10
	for s in ["atk", "def", "vit", "spe"]:
		stats[s] = int(floor(float((int(b.get(s, 1)) + DV) * 2 * niveau) / 100.0)) + 5

func _apprendre_initial() -> void:
	attaques.clear()
	var appr: Array = []
	for e in Donnees.espece(espece_id).get("attaques_niveau", []):
		if int(e[0]) <= niveau:
			appr.append(String(e[1]))
	for id in appr.slice(maxi(0, appr.size() - 4)):
		_ajouter_attaque(id)

func _ajouter_attaque(id: String) -> void:
	var a: Dictionary = Donnees.attaque(id)
	if a.is_empty():
		return
	attaques.append({"id": id, "pp": int(a.get("pp", 10)), "pp_max": int(a.get("pp", 10))})

func reinitialiser_stades() -> void:
	stades = {"atk": 0, "def": 0, "vit": 0, "spe": 0}

func ko() -> bool:
	return pv <= 0

func soigner() -> void:
	pv = stats["pv"]
	for a in attaques:
		a["pp"] = a["pp_max"]

# valeur d'une stat en tenant compte des modificateurs de combat
func stat(nom_stat: String) -> int:
	var s: int = stats[nom_stat]
	var st: int = stades.get(nom_stat, 0)
	var m := (2.0 + st) / 2.0 if st >= 0 else 2.0 / (2.0 - st)
	return maxi(1, int(floor(s * m)))

# gagne de l'experience ; renvoie la liste des messages (montee de niveau, nouvelle attaque...)
func gagner_exp(quantite: int) -> Array:
	var msgs: Array = []
	exp += quantite
	while niveau < 100 and exp >= exp_pour_niveau(niveau + 1):
		var anciens_pv: int = stats["pv"]
		niveau += 1
		_calculer_stats()
		pv += stats["pv"] - anciens_pv
		msgs.append("%s monte au niveau %d !" % [nom, niveau])
		for e in Donnees.espece(espece_id).get("attaques_niveau", []):
			if int(e[0]) == niveau:
				var id := String(e[1])
				var deja := false
				for a in attaques:
					if a["id"] == id:
						deja = true
				if not deja and attaques.size() < 4:
					_ajouter_attaque(id)
					msgs.append("%s apprend %s !" % [nom, Donnees.attaque(id).get("nom", id)])
	return msgs

# ---------- sauvegarde ----------

func en_dictionnaire() -> Dictionary:
	return {"espece": espece_id, "niveau": niveau, "exp": exp, "pv": pv, "attaques": attaques.duplicate(true)}

static func depuis_dictionnaire(d: Dictionary):
	var p = creer(String(d["espece"]), int(d["niveau"]))
	p.exp = int(d.get("exp", p.exp))
	p.pv = clampi(int(d.get("pv", p.pv)), 0, p.stats["pv"])
	var att: Array = []
	for a in d.get("attaques", []):
		if not Donnees.attaque(String(a["id"])).is_empty():
			att.append({"id": String(a["id"]), "pp": int(a["pp"]), "pp_max": int(a["pp_max"])})
	if not att.is_empty():
		p.attaques = att
	return p
