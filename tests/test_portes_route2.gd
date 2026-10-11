extends SceneTree
# Coherence des portes route 2 / route 22 <-> interieurs : arrivees praticables, aller-retour, plus de carte manquante
var erreurs := 0
var legende := {}
func ok(c: bool, msg: String) -> void:
	print(("OK   " if c else "FAIL ") + msg)
	if not c: erreurs += 1
func charger(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/cartes/%s.json" % id))
func marchable(m: Dictionary, x: int, y: int) -> bool:
	var l: Array = m["lignes"]
	if y < 0 or y >= l.size() or x < 0 or x >= String(l[0]).length(): return false
	var s: String = String(l[y])[x]
	return not bool(legende[s].get("solide", false)) and s != "p"
func _init() -> void:
	legende = JSON.parse_string(FileAccess.get_file_as_string("res://data/legende.json"))
	var monde: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/monde.json"))["exterieur"]
	for ext in ["route_2", "route_22"]:
		var m: Dictionary = charger(ext)
		var o: Array = monde[ext]
		for p in m["portes"]:
			var vers: String = p["vers"]
			var tag := "%s (%d,%d) -> %s" % [ext, p["x"], p["y"], vers]
			if not FileAccess.file_exists("res://data/cartes/%s.json" % vers):
				ok(false, tag + " : carte manquante"); continue
			var it: Dictionary = charger(vers)
			var a: Array = p["arrivee"]
			ok(a.size() == 2 and marchable(it, int(a[0]), int(a[1])), tag + " : arrivee praticable " + str(a))
			# retour : une porte de l'interieur ramene a une case voisine de la porte d'origine
			var retour := false
			for q in it["portes"]:
				if q["vers"] == ext:
					var wx: int = int(q["arrivee"][0]) - int(o[0])
					var wy: int = int(q["arrivee"][1]) - int(o[1])
					if absi(wx - int(p["x"])) + absi(wy - int(p["y"])) == 1 and marchable(m, wx, wy):
						retour = true
			ok(retour, tag + " : une porte de retour ramene juste a cote")
	for id in ["poste_garde_route_2", "poste_garde_nord_foret_de_jade", "poste_garde_sud_foret_de_jade", "poste_garde_route_23", "maison_route_2", "cave_taupiqueur_nord"]:
		var m: Dictionary = charger(id)
		var d: Array = m["depart"]
		ok(marchable(m, int(d[0]), int(d[1])), id + " : case de depart praticable")
		for p in m["portes"]:
			ok(String(m["lignes"][p["y"]])[p["x"]] == "p", id + " : porte (%d,%d) sur une case 'p'" % [p["x"], p["y"]])
	print("ERREURS: ", erreurs)
	quit(1 if erreurs > 0 else 0)
