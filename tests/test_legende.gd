extends SceneTree
# Coherence des symboles : data/legende.json est la seule source, aucune carte ne la contredit,
# tous les symboles utilises existent, et deux symboles n'ont jamais le meme nom ni... le meme sens.
var erreurs := 0
func ko(m: String) -> void:
	print("FAIL " + m)
	erreurs += 1
func _init() -> void:
	load("res://scripts/pokemon.gd").deterministe = true
	var f := FileAccess.open("res://data/legende.json", FileAccess.READ)
	var g: Dictionary = JSON.parse_string(f.get_as_text())
	var noms := {}
	for s in g:
		if String(s).length() != 1:
			ko("symbole '%s' : un seul caractere" % s)
		for k in ["nom", "couleur", "solide"]:
			if not g[s].has(k):
				ko("symbole '%s' sans '%s'" % [s, k])
		var n := String(g[s].get("nom", ""))
		if noms.has(n):
			ko("le nom '%s' est utilise par '%s' et '%s'" % [n, noms[n], s])
		noms[n] = s
	var couleurs := {}
	for s in g:
		var c := String(g[s].get("couleur", "")).to_lower()
		if couleurs.has(c):
			ko("couleur %s identique pour '%s' et '%s'" % [c, couleurs[c], s])
		couleurs[c] = s
	for fic in DirAccess.get_files_at("res://data/cartes"):
		if not fic.ends_with(".json"):
			continue
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cartes/" + fic))
		if d.has("legende") and not d["legende"].is_empty():
			ko("%s : legende locale (tout doit etre dans data/legende.json)" % fic)
		var larg := -1
		for l in d["lignes"]:
			if larg >= 0 and String(l).length() != larg:
				ko("%s : lignes de longueurs differentes" % fic)
			larg = String(l).length()
			for ch in String(l):
				if not g.has(ch):
					ko("%s : symbole '%s' inconnu" % [fic, ch])
	print("=== ERREURS : ", erreurs)
	quit(1 if erreurs > 0 else 0)
