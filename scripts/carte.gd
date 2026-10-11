extends Node2D
# Une carte lue depuis data/cartes/<id>.json, ou un "monde" continu fait de plusieurs cartes
# collees ensemble (data/monde.json) : on passe de l'une a l'autre sans changement de carte.
#
# Format du JSON d'une carte (Terry le modifie a la main) :
#   nom          : nom affiche
#   legende      : (facultatif) { "<symbole>": { "nom", "couleur", "solide" } } : les symboles de TOUTES les cartes sont
#                  dans data/legende.json ; la legende d'une carte ne sert qu'a en redefinir un pour cette carte seulement
#   lignes       : tableau de textes, un caractere = une case
#   depart       : [x, y] case de depart si on charge la carte sans arrivee precise
#   portes       : [ { "x", "y", "vers": "<id carte>", "arrivee": [x, y], "depuis": "gauche" } ]
#                  declenche en marchant dessus. "depuis" est optionnel : cote d'ou le joueur doit
#                  arriver ("gauche", "droite", "haut" ou "bas"). Sans "depuis", tous les sens marchent.
#                  Avec "depuis", la case est solide pour les autres cotes (ex : escalier).
#   interactions : [ { "x", "y", "texte": ["page 1", "page 2"], "pose": "<drapeau>" } ]   (touche action, face a la case)
#   declencheurs : [ { "symbole": "g" ou "x"+"y", "evenement": "<id>", "si": "<drapeau>", "si_pas": "<drapeau>" } ]
#                  lance un evenement (data/evenements.json) quand le joueur arrive sur la case
#                  ou "zone": [x1, y1, x2, y2] a la place de x / y : un rectangle de cases (bornes incluses)
#   entree       : [ { "evenement": "<id>", "si": "<drapeau>", "si_pas": "<drapeau>" } ]
#                  joue le premier evenement dont les conditions sont bonnes quand on entre dans la carte par une porte
#   pnj          : [ { "id", "nom", "x", "y", "direction", "couleur", "texte": [...],
#                      "visible_si": "<drapeau>", "cache_si": "<drapeau>", "pose": "<drapeau>",
#                      "evenement": "<id>", "si": "<drapeau>", "si_pas": "<drapeau>", "objet": true } ]
#                  les PNJ sont solides ; "visible_si" / "cache_si" les montrent ou les cachent selon l'histoire
#
# Une case de legende avec "coupable": true (ex : l'arbuste) est solide jusqu'a ce que le joueur la coupe avec COUPE
# (touche action face a elle) ; elle devient alors la case "apres_coupe" (par defaut "." = herbe). L'etat est sauvegarde
# dans les drapeaux ("coupe@<carte>@x,y").
#
# Dans la legende, une case peut avoir "saut": "bas" (ou "haut", "gauche", "droite") : elle ne se franchit que
# dans ce sens-la, en sautant par-dessus (comme les rebords du jeu). Une case dont le nom commence par "rebord"
# est un rebord vers le bas sans rien ecrire de plus.
#
# data/monde.json : { "<groupe>": { "<id carte>": [x, y], ... } }
#   [x, y] = position (en cases) du coin haut-gauche de la carte dans le monde. Les x, y des portes,
#   interactions, PNJ... de chaque JSON restent LOCAUX a la carte ; en revanche "arrivee" (portes) et les
#   coordonnees des evenements sont en coordonnees du monde (la premiere carte du groupe en est l'origine
#   si elle est en [0, 0]).

const TAILLE := 16

var dossier := "res://data/cartes"   # change par les tests
var fichier_monde := "res://data/monde.json"
var fichier_legende := "res://data/legende.json"   # symboles communs a toutes les cartes
var id := ""
var nom := ""
var largeur := 0                     # taille de l'ensemble charge (cases)
var hauteur := 0
var origine := Vector2i.ZERO         # coin haut-gauche de l'ensemble (peut etre negatif)
var depart := Vector2i.ZERO
var depart_defini := false
var pnj_donnees: Array = []
var declencheurs: Array = []
var cases_coupees := {}              # cases (monde) dont l'arbuste "coupable" a ete coupe
var entrees: Array = []              # evenements joues quand le joueur entre dans la carte par une porte
var _regions: Array = []             # { id, origine, lignes, legende, largeur, hauteur }
var _portes := {}
var _interactions := {}

func _lire_json(chemin: String):
	if not FileAccess.file_exists(chemin):
		push_error("Fichier introuvable : " + chemin)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(chemin)) != OK:
		push_error("JSON invalide dans %s (ligne %d) : %s" % [chemin, json.get_error_line(), json.get_error_message()])
		return null
	return json.data

# groupe de cartes contigues auquel appartient id_carte (sinon : la carte seule en [0, 0])
func _groupe(id_carte: String) -> Dictionary:
	if fichier_monde != "" and FileAccess.file_exists(fichier_monde):
		var monde = _lire_json(fichier_monde)
		if monde is Dictionary:
			for g in monde:
				if monde[g] is Dictionary and monde[g].has(id_carte):
					return monde[g]
	return {id_carte: [0, 0]}

func charger(id_carte: String) -> bool:
	var groupe := _groupe(id_carte)
	var ids: Array = [id_carte]
	for k in groupe:
		if k != id_carte:
			ids.append(k)
	var legende_commune: Dictionary = {}
	if fichier_legende != "" and FileAccess.file_exists(fichier_legende):
		var lc = _lire_json(fichier_legende)
		if lc is Dictionary:
			legende_commune = lc
	_regions.clear()
	_portes.clear()
	_interactions.clear()
	pnj_donnees = []
	declencheurs = []
	entrees = []
	cases_coupees = {}
	for rid in ids:
		var d = _lire_json("%s/%s.json" % [dossier, rid])
		if not (d is Dictionary):
			if rid == id_carte:
				return false
			continue
		var o: Array = groupe.get(rid, [0, 0])
		var legende_carte: Dictionary = legende_commune.duplicate(true)
		legende_carte.merge(d.get("legende", {}), true)   # la legende d'une carte, si elle en a une, prime sur la commune
		var r := {"id": rid, "origine": Vector2i(int(o[0]), int(o[1])), "lignes": d.get("lignes", []),
			"legende": legende_carte, "hauteur": 0, "largeur": 0, "donnees": d}
		r["hauteur"] = r["lignes"].size()
		for l in r["lignes"]:
			r["largeur"] = maxi(r["largeur"], String(l).length())
		_regions.append(r)
	# boite englobante
	var coin_min: Vector2i = _regions[0]["origine"]
	var coin_max: Vector2i = coin_min
	for r in _regions:
		coin_min = coin_min.min(r["origine"])
		coin_max = coin_max.max(r["origine"] + Vector2i(r["largeur"], r["hauteur"]))
	origine = coin_min
	largeur = coin_max.x - coin_min.x
	hauteur = coin_max.y - coin_min.y
	var premiere: Dictionary = _regions[0]
	id = id_carte
	nom = premiere["donnees"].get("nom", id_carte)
	depart_defini = premiere["donnees"].has("depart")
	var dep: Array = premiere["donnees"].get("depart", [0, 0])
	depart = premiere["origine"] + Vector2i(int(dep[0]), int(dep[1]))
	# portes, interactions, pnj, declencheurs : coordonnees locales -> coordonnees du monde
	for r in _regions:
		var d: Dictionary = r["donnees"]
		var o: Vector2i = r["origine"]
		for p in d.get("portes", []):
			var q: Dictionary = p.duplicate(true)
			q["x"] = int(p["x"]) + o.x
			q["y"] = int(p["y"]) + o.y
			_portes[Vector2i(q["x"], q["y"])] = q
		for i in d.get("interactions", []):
			var q: Dictionary = i.duplicate(true)
			q["x"] = int(i["x"]) + o.x
			q["y"] = int(i["y"]) + o.y
			_interactions[Vector2i(q["x"], q["y"])] = q
		for n in d.get("pnj", []):
			var q: Dictionary = n.duplicate(true)
			q["x"] = int(n["x"]) + o.x
			q["y"] = int(n["y"]) + o.y
			pnj_donnees.append(q)
		for t in d.get("declencheurs", []):
			var q: Dictionary = t.duplicate(true)
			if q.has("zone"):     # rectangle [x1, y1, x2, y2] (inclus) : un declencheur par case
				var z: Array = q["zone"]
				q.erase("zone")
				for zy in range(int(z[1]), int(z[3]) + 1):
					for zx in range(int(z[0]), int(z[2]) + 1):
						var qz: Dictionary = q.duplicate(true)
						qz["x"] = zx + o.x
						qz["y"] = zy + o.y
						declencheurs.append(qz)
				continue
			if q.has("symbole"):
				q["_region"] = r["id"]
			else:
				q["x"] = int(t.get("x", 0)) + o.x
				q["y"] = int(t.get("y", 0)) + o.y
			declencheurs.append(q)
	entrees = _regions[0]["donnees"].get("entree", []).duplicate(true)
	_verifier()
	queue_redraw()
	return true

# previent dans la console si un JSON a un probleme (symbole inconnu, ligne trop courte...)
func _verifier() -> void:
	for r in _regions:
		var rid: String = r["id"]
		for y in r["hauteur"]:
			var l := String(r["lignes"][y])
			if l.length() != r["largeur"]:
				push_warning("%s : la ligne %d fait %d caracteres au lieu de %d" % [rid, y, l.length(), r["largeur"]])
			for x in l.length():
				if not r["legende"].has(l[x]):
					push_warning("%s : symbole '%s' absent de la legende (case %d,%d)" % [rid, l[x], x, y])
	for c in _portes:
		var p: Dictionary = _portes[c]
		if not dans_carte(c):
			push_warning("porte hors de la carte en %s" % [c])
		elif not ["", "gauche", "droite", "haut", "bas"].has(String(p.get("depuis", ""))):
			push_warning("porte en %s : \"depuis\" doit etre gauche, droite, haut ou bas" % [c])
		elif solide(c):
			push_warning("%s : la porte en %s est sur une case solide ('%s'), on ne pourra pas l'atteindre" % [region_id_a(c), c, symbole(c)])
	# une case dont la legende s'appelle "porte..." (non solide) devrait avoir une entree dans "portes"
	for r in _regions:
		for y in r["hauteur"]:
			for x in String(r["lignes"][y]).length():
				var c: Vector2i = r["origine"] + Vector2i(x, y)
				var nom_case := String(r["legende"].get(symbole(c), {}).get("nom", ""))
				if nom_case.begins_with("porte") and not solide(c) and not _portes.has(c):
					push_warning("%s : case 'porte' en %s sans entree dans \"portes\"" % [r["id"], c - r["origine"]])
	for c in _interactions:
		if not dans_carte(c):
			push_warning("interaction hors de la carte en %s" % [c])
	var occupees := {}
	for n in pnj_donnees:
		var c := Vector2i(int(n.get("x", -1)), int(n.get("y", -1)))
		var qui := "%s (%s)" % [n.get("nom", "?"), n.get("id", "?")]
		if not dans_carte(c):
			push_warning("le PNJ %s est hors de la carte en %s" % [qui, c])
		elif solide(c) and not n.get("objet", false) and not pnj_ok(c):
			push_warning("le PNJ %s est sur une case solide en %s" % [qui, c])
		elif _portes.has(c):
			push_warning("le PNJ %s est sur une porte en %s" % [qui, c])
		if occupees.has(c) and not n.has("visible_si") and not n.has("cache_si"):
			push_warning("deux PNJ sur la meme case %s" % [c])
		occupees[c] = true
		if not ["haut", "bas", "gauche", "droite"].has(String(n.get("direction", "bas"))):
			push_warning("le PNJ %s a une direction invalide" % [qui])

# un PNJ peut se tenir sur cette case solide si sa legende a "pnj_ok": true (ex : le comptoir)
func pnj_ok(c: Vector2i) -> bool:
	var r := _region_a(c)
	if r.is_empty():
		return false
	return bool(r["legende"].get(symbole(c), {}).get("pnj_ok", false))

# carte (region) qui contient la case c du monde, ou {}
func _region_a(c: Vector2i) -> Dictionary:
	for r in _regions:
		var l: Vector2i = c - r["origine"]
		if l.y >= 0 and l.y < r["hauteur"] and l.x >= 0 and l.x < String(r["lignes"][l.y]).length():
			return r
	return {}

func region_id_a(c: Vector2i) -> String:
	return String(_region_a(c).get("id", ""))

func dans_carte(c: Vector2i) -> bool:
	return not _region_a(c).is_empty()

func symbole(c: Vector2i) -> String:
	var r := _region_a(c)
	if r.is_empty():
		return ""
	var l: Vector2i = c - r["origine"]
	var ch := String(r["lignes"][l.y])[l.x]
	if cases_coupees.has(c):
		return String(r["legende"].get(ch, {}).get("apres_coupe", "."))
	return ch

# case "coupable" (legende : "coupable": true) qui n'a pas encore ete coupee
func est_coupable(c: Vector2i) -> bool:
	var r := _region_a(c)
	if r.is_empty() or cases_coupees.has(c):
		return false
	var l: Vector2i = c - r["origine"]
	return bool(r["legende"].get(String(r["lignes"][l.y])[l.x], {}).get("coupable", false))

# type de rencontre sauvage de la case ("herbe"... legende : "rencontre"), "" si aucune
func rencontre_a(c: Vector2i) -> String:
	var r := _region_a(c)
	if r.is_empty():
		return ""
	var l: Vector2i = c - r["origine"]
	return String(r["legende"].get(symbole(c), {}).get("rencontre", ""))

# coordonnees locales (dans sa carte JSON) de la case c du monde
func local_de(c: Vector2i) -> Vector2i:
	var r := _region_a(c)
	return c - r["origine"] if not r.is_empty() else c

func couper(c: Vector2i) -> void:
	cases_coupees[c] = true
	queue_redraw()

# remet en etat une case coupee (carte "rid", coordonnees locales) : utilise au chargement a partir des drapeaux
func marquer_coupe(rid: String, local: Vector2i) -> void:
	for r in _regions:
		if String(r["id"]) == rid:
			cases_coupees[r["origine"] + local] = true
	queue_redraw()

func solide(c: Vector2i) -> bool:
	var r := _region_a(c)
	if r.is_empty():
		return true
	var def: Dictionary = r["legende"].get(symbole(c), {})
	return bool(def.get("solide", false))

# sens dans lequel on peut sauter par-dessus la case (rebord), ou ZERO si ce n'est pas un rebord
func sens_unique(c: Vector2i) -> Vector2i:
	var r := _region_a(c)
	if r.is_empty():
		return Vector2i.ZERO
	var def: Dictionary = r["legende"].get(symbole(c), {})
	var par_defaut := "bas" if String(def.get("nom", "")).begins_with("rebord") else ""
	match String(def.get("saut", par_defaut)):
		"bas": return Vector2i.DOWN
		"haut": return Vector2i.UP
		"gauche": return Vector2i.LEFT
		"droite": return Vector2i.RIGHT
	return Vector2i.ZERO

func porte(c: Vector2i) -> Dictionary:
	return _portes.get(c, {})

# direction de deplacement necessaire pour declencher la porte (ZERO = n'importe laquelle)
func sens_porte(p: Dictionary) -> Vector2i:
	match String(p.get("depuis", "")):
		"gauche": return Vector2i.RIGHT
		"droite": return Vector2i.LEFT
		"haut": return Vector2i.DOWN
		"bas": return Vector2i.UP
	return Vector2i.ZERO

# declencheurs dont la case correspond (le test des drapeaux se fait dans main)
func declencheurs_en(c: Vector2i) -> Array:
	var res: Array = []
	for t in declencheurs:
		if t.has("symbole"):
			if region_id_a(c) == String(t["_region"]) and symbole(c) == String(t["symbole"]):
				res.append(t)
		elif int(t.get("x", -1)) == c.x and int(t.get("y", -1)) == c.y:
			res.append(t)
	return res

func interaction(c: Vector2i) -> Dictionary:
	return _interactions.get(c, {})

func _draw() -> void:
	for r in _regions:
		var o: Vector2i = r["origine"]
		for y in r["hauteur"]:
			var l := String(r["lignes"][y])
			for x in l.length():
				var ch := l[x]
				if not cases_coupees.is_empty() and cases_coupees.has(Vector2i(o.x + x, o.y + y)):
					ch = String(r["legende"].get(ch, {}).get("apres_coupe", "."))
				var def: Dictionary = r["legende"].get(ch, {})
				var couleur := Color(def.get("couleur", "#ff00ff"))
				draw_rect(Rect2((o.x + x) * TAILLE, (o.y + y) * TAILLE, TAILLE, TAILLE), couleur)
