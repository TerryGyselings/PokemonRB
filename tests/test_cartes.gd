extends SceneTree
# Verifie toutes les cartes de data/cartes : portes qui menent a une carte existante,
# arrivee sur une case libre, depart libre, interactions dans la carte, portes de retour.
var erreurs := 0
func ko(msg: String) -> void:
	print("FAIL " + msg)
	erreurs += 1
func _init() -> void:
	var C = load("res://scripts/carte.gd")
	var ids: Array = []
	for f in DirAccess.get_files_at("res://data/cartes"):
		if f.ends_with(".json"):
			ids.append(f.get_basename())
	var cartes := {}
	for id in ids:
		var c = C.new()
		root.add_child(c)
		if not c.charger(id):
			ko("%s ne se charge pas" % id)
			continue
		cartes[id] = c
	var evts := {}
	var f := FileAccess.open("res://data/evenements.json", FileAccess.READ)
	if f != null:
		evts = JSON.parse_string(f.get_as_text())
	for id in cartes:
		var c = cartes[id]
		for t in c.declencheurs:
			if not evts.has(String(t.get("evenement", ""))):
				ko("%s : declencheur vers l'evenement inconnu '%s'" % [id, t.get("evenement", "")])
		for e in c.entrees:
			if not evts.has(String(e.get("evenement", ""))):
				ko("%s : entree vers l'evenement inconnu '%s'" % [id, e.get("evenement", "")])
		if c.depart_defini and c.solide(c.depart):
			ko("%s : depart %s sur une case solide" % [id, c.depart])
		for pos in c._portes:
			var p: Dictionary = c._portes[pos]
			var vers := String(p["vers"])
			if not cartes.has(vers):
				ko("%s : porte %s vers '%s' qui n'existe pas" % [id, pos, vers])
				continue
			var a: Array = p.get("arrivee", [])
			if a.size() != 2:
				ko("%s : porte %s sans arrivee" % [id, pos])
				continue
			var arrivee := Vector2i(int(a[0]), int(a[1]))
			if cartes[vers].solide(arrivee):
				ko("%s : porte %s -> arrivee %s sur une case solide de %s" % [id, pos, arrivee, vers])
			if cartes[vers].porte(arrivee).size() > 0 and cartes[vers].sens_porte(cartes[vers].porte(arrivee)) == Vector2i.ZERO:
				ko("%s : porte %s -> arrivee %s est elle-meme une porte de %s" % [id, pos, arrivee, vers])
		var vus := {}
		for n in c.pnj_donnees:
			var pos := Vector2i(int(n["x"]), int(n["y"]))
			if not c.dans_carte(pos) or (c.solide(pos) and not n.get("objet", false) and not c.pnj_ok(pos)):
				ko("%s : PNJ %s en %s hors carte ou sur une case solide" % [id, n.get("id", "?"), pos])
			if c._portes.has(pos):
				ko("%s : PNJ %s sur une porte en %s" % [id, n.get("id", "?"), pos])
			if vus.has(n.get("id", "")):
				ko("%s : id de PNJ en double : %s" % [id, n.get("id", "")])
			vus[n.get("id", "")] = true
		for pos in c._interactions:
			if not c.dans_carte(pos):
				ko("%s : interaction hors carte %s" % [id, pos])
	for eid in evts:
		for a in evts[eid]:
			if a.has("carte") and not cartes.has(String(a["carte"])):
				ko("evenement %s : carte inconnue '%s'" % [eid, a["carte"]])
	print("%d cartes verifiees" % cartes.size())
	print("=== ERREURS : %d" % erreurs)
	quit()
