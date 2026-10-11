extends RefCounted
# Acces aux donnees de jeu (data/pokemon.json, attaques.json, types.json) avec cache.
# Les fichiers sont relus automatiquement s'ils changent (pratique pendant que tu les modifies).

static var dossier := "res://data"
static var _cache := {}
static var _heure := {}

static func _lire(nom_fichier: String) -> Dictionary:
	var chemin := "%s/%s.json" % [dossier, nom_fichier]
	if not FileAccess.file_exists(chemin):
		push_error("Fichier de donnees introuvable : " + chemin)
		return {}
	var h := FileAccess.get_modified_time(chemin)
	if _cache.has(chemin) and _heure.get(chemin, -1) == h:
		return _cache[chemin]
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(chemin)) != OK:
		push_error("JSON invalide dans %s (ligne %d) : %s" % [chemin, json.get_error_line(), json.get_error_message()])
		return {}
	_cache[chemin] = json.data
	_heure[chemin] = h
	return json.data

static func espece(id: String) -> Dictionary:
	var d: Dictionary = _lire("pokemon")
	if not d.has(id):
		push_error("Espece inconnue : " + id)
		return {}
	return d[id]

static func attaque(id: String) -> Dictionary:
	var d: Dictionary = _lire("attaques")
	if not d.has(id):
		push_error("Attaque inconnue : " + id)
		return {}
	return d[id]

# regles generales modifiables (data/regles.json) : proba_shiny, niveau_max, tailles d'equipe/boites...
static func regle(nom: String, defaut = 0):
	return _lire("regles").get(nom, defaut)

# nature : { "nom", "plus", "moins" } ; talent : { "nom", "description" } ; courbe : liste des EXP de niv. 1 a 100
static func nature(id: String) -> Dictionary:
	return _lire("natures").get(id, {})

static func toutes_les_natures() -> Array:
	return _lire("natures").keys()

static func talent(id: String) -> Dictionary:
	return _lire("talents").get(id, {})

static func courbe(id: String) -> Array:
	return _lire("courbes").get(id, _lire("courbes").get("moyenne_lente", []))

static func nom_type(id: String) -> String:
	return String(_lire("types").get("noms", {}).get(id, id.capitalize()))

# multiplicateur d'efficacite d'un type d'attaque contre une liste de types defenseurs
static func efficacite(type_attaque: String, types_defenseur: Array) -> float:
	var tab: Dictionary = _lire("types").get("efficacite", {}).get(type_attaque, {})
	var m := 1.0
	for t in types_defenseur:
		m *= float(tab.get(t, 1.0))
	return m

# identifiants de toutes les especes, dans l'ordre du Pokedex
static func toutes_les_especes() -> Array:
	var d: Dictionary = _lire("pokemon")
	var ids: Array = d.keys()
	ids.sort_custom(func(a, b): return int(d[a].get("numero", 999)) < int(d[b].get("numero", 999)))
	return ids

# un objet de data/objets.json : { "nom", "prix", "description", "cle" } ({} s'il n'existe pas)
static func objet(id: String) -> Dictionary:
	var d: Dictionary = _lire("objets")
	return d.get(id, {})

static func nom_objet(id: String) -> String:
	return String(objet(id).get("nom", id.replace("_", " ").to_upper()))

# table de rencontres sauvages d'une carte (data/rencontres.json) : { "taux": %/pas, "pokemon": [{espece, min, max, poids}] }
static func rencontres(carte_id: String, type: String) -> Dictionary:
	return _lire("rencontres").get(carte_id, {}).get(type, {})

# tire un Pokemon dans une table (selon les poids) : { "espece", "niveau" } ; {} si la table est vide
static func tirer_rencontre(table: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var liste: Array = table.get("pokemon", [])
	var total := 0
	for e in liste:
		total += int(e.get("poids", 1))
	if total <= 0:
		return {}
	var t := rng.randi_range(1, total)
	for e in liste:
		t -= int(e.get("poids", 1))
		if t <= 0:
			return {"espece": String(e["espece"]), "niveau": rng.randi_range(int(e["min"]), int(e["max"]))}
	return {}
