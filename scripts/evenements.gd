extends RefCounted
# Joue les evenements decrits dans data/evenements.json.
# Format : { "<id>": [ action, action, ... ] }
# Actions disponibles (une cle par action) :
#   { "dire": ["page 1", "page 2"], "pose": "<drapeau>" }    dialogue (le drapeau est pose a la fin, optionnel)
#   { "pose": "<drapeau>" }                                   pose un drapeau d'histoire
#   { "attendre": 0.5 }                                       pause en secondes
#   { "pnj_vers_joueur": "<id pnj>" }                         le PNJ marche jusqu'a cote du joueur et le regarde
#   { "pnj_marche": { "id": "<id pnj>", "vers": [x, y] } }    le PNJ marche jusqu'a la case
#   { "escorte": { "pnj": "<id pnj>", "vers": [x, y] } }       le PNJ marche jusqu'a la case et le joueur le suit pas a pas
#   { "pnj_regarde_joueur": "<id pnj>" }
#   { "joueur_regarde": "haut" | "bas" | "gauche" | "droite" }
#   { "joueur_marche": ["haut", "haut", "gauche"] }             pas dans ces directions, sans pause entre les pas
#   { "joueur_vers": [x, y] }                                  le joueur marche d'un trait jusqu'a la case (plus court chemin)
#   { "carte": "<id carte>", "arrivee": [x, y] }              changement de carte avec fondu
#   { "pnj_place": { "id": "<id pnj>", "x": 7, "y": 11, "direction": "haut" } }   deplace un PNJ d'un coup (avant de le faire marcher)
#   { "pnj_tourne": { "id": "<id pnj>", "direction": "haut" } }
#   { "choix": { "question": "texte", "oui": [actions], "non": [actions] } }   question OUI / NON
#   { "donne_pokemon": { "espece": "salameche", "niveau": 5 } }   ajoute un Pokemon a l'equipe
#   { "donne_objet": { "id": "colis_chen", "quantite": 1 } }  ajoute un objet au sac (data/objets.json) et le dit
#   { "retire_objet": { "id": "colis_chen" } }                retire un objet du sac
#   { "demo_capture": { "espece": "rattata", "niveau": 3, "dresseur": "VIEIL HOMME" } }   demonstration de capture (ecran de combat)
#   { "pc": true }                                                ouvre le PC (stockage des POKeMON)
#   { "boutique": { "stock": ["poke_ball", "potion"] } }       ouvre la boutique (ACHETER / VENDRE / SORTIR)
#   { "soigner": true }                                       soigne toute l'equipe
#   { "si": { "drapeau": "<nom>", "alors": [actions], "sinon": [actions] } }
#   { "evenement": "<id>" }                                   joue un autre evenement
#   { "fondu": 0.6 }                                          ecran noir un instant (soin, passage de temps...)
#   { "point_soin": { "carte": "<id carte>", "arrivee": [x, y] } }   dernier endroit ou l'equipe a ete soignee (on y revient si tous les Pokemon sont K.O.)
#   { "combat": { "nom": "RIVAL", "equipe": [ { "espece", "niveau", "si": "<drapeau>" } ], "pose_victoire": "<drapeau>", "blackout": false } }
#       blackout (vrai par defaut) : si tous les Pokemon du joueur sont K.O., il revient au point de soin, l'equipe est soignee
#       et la suite de l'evenement est annulee. "blackout": false pour un combat d'histoire qui continue quand meme.

const Pnj := preload("res://scripts/pnj.gd")
const Donnees := preload("res://scripts/donnees.gd")

var chemin_fichier := "res://data/evenements.json"
var _main
var _stop := false   # un blackout interrompt l'evenement en cours

func installer(m) -> void:
	_main = m

func _lire() -> Dictionary:
	if not FileAccess.file_exists(chemin_fichier):
		push_error("Fichier d'evenements introuvable : " + chemin_fichier)
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(chemin_fichier)) != OK:
		push_error("JSON invalide dans %s (ligne %d) : %s" % [chemin_fichier, json.get_error_line(), json.get_error_message()])
		return {}
	return json.data

func existe(id: String) -> bool:
	return _lire().has(id)

# a utiliser avec await si on veut attendre la fin
func jouer(id: String) -> void:
	var tous := _lire()
	if not tous.has(id):
		push_error("Evenement inconnu : " + id)
		return
	_main.evenement_en_cours = true
	_main.joueur.bloque = true
	_stop = false
	await _liste(tous[id])
	_stop = false
	_main.evenement_en_cours = false
	_main.joueur.bloque = false

func _liste(actions: Array) -> void:
	for a in actions:
		if _stop:
			break
		await _action(a)

func _action(a: Dictionary) -> void:
	if a.has("dire"):
		await _main.dire_attendre(a["dire"], String(a.get("pose", "")))
	elif a.has("pose"):
		_main.poser_drapeau(String(a["pose"]))
	elif a.has("attendre"):
		await _main.get_tree().create_timer(float(a["attendre"])).timeout
	elif a.has("pnj_vers_joueur"):
		await _pnj_vers_joueur(String(a["pnj_vers_joueur"]))
	elif a.has("pnj_marche"):
		var m: Dictionary = a["pnj_marche"]
		var p = _pnj(String(m["id"]))
		if p != null:
			var vers: Array = m["vers"]
			await p.marcher(_main.chemin(p.case, Vector2i(int(vers[0]), int(vers[1]))))
	elif a.has("escorte"):
		await _escorte(a["escorte"])
	elif a.has("pnj_regarde_joueur"):
		var p = _pnj(String(a["pnj_regarde_joueur"]))
		if p != null:
			p.tourner_vers(_main.joueur.case)
	elif a.has("joueur_regarde"):
		_main.joueur.direction = Pnj.vers_direction(String(a["joueur_regarde"]))
		_main.joueur.queue_redraw()
	elif a.has("joueur_marche"):
		for nom in a["joueur_marche"]:
			await _pas_joueur(Pnj.vers_direction(String(nom)))
	elif a.has("joueur_vers"):
		var v: Array = a["joueur_vers"]
		for c in _main.chemin(_main.joueur.case, Vector2i(int(v[0]), int(v[1]))):
			await _pas_joueur(c - _main.joueur.case)
	elif a.has("carte"):
		var ar: Array = a.get("arrivee", [])
		await _main.changer_carte(String(a["carte"]), Vector2i(int(ar[0]), int(ar[1])) if ar.size() == 2 else null)
	elif a.has("pnj_place"):
		var t: Dictionary = a["pnj_place"]
		for d in _main.carte.pnj_donnees:
			if String(d.get("id", "")) == String(t["id"]):
				d["x"] = int(t["x"])
				d["y"] = int(t["y"])
				if t.has("direction"):
					d["direction"] = String(t["direction"])
		_main._creer_pnj()
	elif a.has("fondu"):
		var t: Tween = _main.create_tween()
		t.tween_property(_main.voile, "modulate:a", 1.0, 0.25)
		await t.finished
		await _main.get_tree().create_timer(float(a["fondu"])).timeout
		t = _main.create_tween()
		t.tween_property(_main.voile, "modulate:a", 0.0, 0.25)
		await t.finished
	elif a.has("point_soin"):
		var ps: Dictionary = a["point_soin"]
		_main.point_soin = {"carte": String(ps["carte"]), "arrivee": [int(ps["arrivee"][0]), int(ps["arrivee"][1])]}
	elif a.has("pnj_tourne"):
		var t: Dictionary = a["pnj_tourne"]
		var p = _pnj(String(t["id"]))
		if p != null:
			p.direction = Pnj.vers_direction(String(t["direction"]))
			p.sauver()
			p.queue_redraw()
	elif a.has("choix"):
		var c: Dictionary = a["choix"]
		if await _main.oui_non(String(c["question"])):
			await _liste(c.get("oui", []))
		else:
			await _liste(c.get("non", []))
	elif a.has("donne_pokemon"):
		var d: Dictionary = a["donne_pokemon"]
		_main.donner_pokemon(String(d["espece"]), int(d["niveau"]))
		var nom := String(_main.equipe[-1].nom).to_upper()
		await _main.dire_attendre(["Tu recois %s !" % nom])
	elif a.has("donne_objet"):
		var o: Dictionary = a["donne_objet"]
		var q := int(o.get("quantite", 1))
		_main.donner_objet(String(o["id"]), q)
		var nom_o: String = Donnees.nom_objet(String(o["id"]))
		await _main.dire_attendre(["${nom_joueur} recoit %s%s !" % [nom_o, (" x%d" % q) if q > 1 else ""]])
	elif a.has("retire_objet"):
		var o2: Dictionary = a["retire_objet"]
		_main.retirer_objet(String(o2["id"]), int(o2.get("quantite", 1)))
	elif a.has("demo_capture"):
		var dc: Dictionary = a["demo_capture"]
		var t: Tween = _main.create_tween()
		t.tween_property(_main.voile, "modulate:a", 1.0, 0.3)
		await t.finished
		await _main.combat.demo_capture(String(dc["espece"]), int(dc.get("niveau", 3)), String(dc.get("dresseur", "Dresseur")))
		_main.voile.modulate.a = 0.0
	elif a.has("pc"):
		await _main.pc.ouvrir()
	elif a.has("boutique"):
		await _main.boutique.ouvrir(a["boutique"].get("stock", []))
	elif a.has("soigner"):
		for p in _main.equipe:
			p.soigner()
	elif a.has("si"):
		var s: Dictionary = a["si"]
		if _main.a_drapeau(String(s["drapeau"])):
			await _liste(s.get("alors", []))
		else:
			await _liste(s.get("sinon", []))
	elif a.has("evenement"):
		var tous := _lire()
		if tous.has(String(a["evenement"])):
			await _liste(tous[String(a["evenement"])])
		else:
			push_error("Evenement inconnu : " + String(a["evenement"]))
	elif a.has("combat"):
		await _combat(a["combat"])
	else:
		push_warning("Action d'evenement inconnue : %s" % [a])

func _pnj(id: String):
	for p in _main._pnj:
		if String(p.donnees.get("id", "")) == id:
			return p
	push_warning("Evenement : PNJ '%s' absent de la carte (visible ?)" % id)
	return null

func _pnj_vers_joueur(id: String) -> void:
	var p = _pnj(id)
	if p == null:
		return
	var jc: Vector2i = _main.joueur.case
	var meilleur: Array = []
	var trouve := false
	for d in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
		var cible: Vector2i = jc + d
		if cible == p.case:
			meilleur = []
			trouve = true
			break
		var c: Array = _main.chemin(p.case, cible)
		if not c.is_empty() and (not trouve or c.size() < meilleur.size()):
			meilleur = c
			trouve = true
	if trouve:
		await p.marcher(meilleur)
	p.tourner_vers(jc)

# le PNJ ouvre la marche, le joueur avance dans la case que le PNJ vient de quitter
func _escorte(e: Dictionary) -> void:
	var p = _pnj(String(e["pnj"]))
	if p == null:
		return
	var vers: Array = e["vers"]
	var trace: Array = _main.chemin(p.case, Vector2i(int(vers[0]), int(vers[1])))
	for c in trace:
		var avant: Vector2i = p.case
		var t: Tween = p.pas(c)
		var delta: Vector2i = avant - _main.joueur.case
		if absi(delta.x) + absi(delta.y) == 1:
			_main.joueur.deplacer(delta)
		else:
			_main.joueur.placer(avant)
		await t.finished
		await _main.get_tree().process_frame
	p.sauver()

# un pas du joueur, puis on reprend des qu'il est arrive (donc les pas s'enchainent sans pause)
func _pas_joueur(d: Vector2i) -> void:
	if _main.joueur.deplacer(d):
		await _main.joueur.arrive

func _combat(c: Dictionary) -> void:
	var Pokemon := load("res://scripts/pokemon.gd")
	var ennemis: Array = []
	for e in c.get("equipe", []):
		if _main.conditions_ok(e):
			ennemis.append(Pokemon.creer(String(e["espece"]), int(e["niveau"])))
	if ennemis.is_empty() or _main.equipe.is_empty():
		push_warning("Combat impossible : equipe vide")
		return
	for e in ennemis:
		_main.enregistrer_vu(e.espece_id)
	var t: Tween = _main.create_tween()
	t.tween_property(_main.voile, "modulate:a", 1.0, 0.3)
	await t.finished
	var gagne: bool = await _main.combat.combattre(_main.equipe, ennemis, String(c.get("nom", "Dresseur")))
	_main.voile.modulate.a = 0.0
	if gagne and c.has("pose_victoire"):
		_main.poser_drapeau(String(c["pose_victoire"]))
	if not gagne and bool(c.get("blackout", true)):
		await _main.blackout()
		_stop = true
