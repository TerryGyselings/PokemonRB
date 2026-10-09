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

static func categorie_speciale(type_attaque: String) -> bool:
	return _lire("types").get("speciaux", []).has(type_attaque)

# multiplicateur d'efficacite d'un type d'attaque contre une liste de types defenseurs
static func efficacite(type_attaque: String, types_defenseur: Array) -> float:
	var tab: Dictionary = _lire("types").get("efficacite", {}).get(type_attaque, {})
	var m := 1.0
	for t in types_defenseur:
		m *= float(tab.get(t, 1.0))
	return m
