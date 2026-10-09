extends CanvasLayer
# Ecran de combat (style Pokemon Rouge/Bleu, formules de la 1re generation).
# Utilisation : var victoire = await combat.combattre(equipe, ennemis, "RIVAL")
#   equipe / ennemis : listes de Pokemon (scripts/pokemon.gd)
# Touches : fleches pour le curseur, Entree/Espace/E pour valider, X/Retour arriere pour annuler.
# Pas encore fonctionnel : SAC, POKEMON (changer), FUITE (impossible contre un dresseur).

signal touche(nom: String)

const Donnees := preload("res://scripts/donnees.gd")
const LARGEUR_BARRE := 110.0

var auto := false                 # tests : pas d'attente, choix lus dans script_choix (0 par defaut)
var script_choix: Array = []
var rng := RandomNumberGenerator.new()
var journal: Array = []           # tous les messages affiches (utile pour les tests)
var equipe: Array = []
var ennemis: Array = []
var actif_j
var actif_e
var en_cours := false

var _fond: ColorRect
var _sprite := {}                 # "j" / "e" -> ColorRect
var _info := {}                   # "j" / "e" -> { nom, niv, rempli, pv }
var _boite: Panel
var _texte: Label
var _menu_zone: Panel
var _attaques_zone: Panel
var _fleche: Label

func _ready() -> void:
	layer = 20
	visible = false
	rng.randomize()
	_construire()

func _input(event: InputEvent) -> void:
	if not visible or auto:
		return
	for nom in ["action", "annuler", "haut", "bas", "gauche", "droite"]:
		if event.is_action_pressed(nom):
			get_viewport().set_input_as_handled()
			touche.emit(nom)
			return

func appuyer(nom: String) -> void:
	touche.emit(nom)

# ---------- construction de l'ecran ----------

func _panneau(r: Rect2) -> Panel:
	var p := Panel.new()
	p.position = r.position
	p.size = r.size
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.97, 0.97, 0.92)
	s.border_color = Color.BLACK
	s.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", s)
	return p

func _label(parent: Node, pos: Vector2, taille := 13) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_color_override("font_color", Color.BLACK)
	l.add_theme_font_size_override("font_size", taille)
	parent.add_child(l)
	return l

func _construire() -> void:
	_fond = ColorRect.new()
	_fond.color = Color(0.93, 0.95, 0.88)
	_fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fond)
	for cote in ["e", "j"]:
		var s := ColorRect.new()
		s.size = Vector2(72, 72) if cote == "e" else Vector2(88, 88)
		s.position = Vector2(344, 30) if cote == "e" else Vector2(56, 112)
		add_child(s)
		_sprite[cote] = s
		var p := _panneau(Rect2(12, 12, 230, 50) if cote == "e" else Rect2(246, 150, 224, 62))
		add_child(p)
		var nom := _label(p, Vector2(8, 2))
		var niv := _label(p, Vector2(150, 2))
		var fond := ColorRect.new()
		fond.color = Color(0.25, 0.25, 0.25)
		fond.position = Vector2(60, 26)
		fond.size = Vector2(LARGEUR_BARRE + 4, 10)
		p.add_child(fond)
		var rempli := ColorRect.new()
		rempli.position = Vector2(2, 2)
		rempli.size = Vector2(LARGEUR_BARRE, 6)
		fond.add_child(rempli)
		var pl := _label(p, Vector2(8, 21), 10)
		pl.text = "PV"
		var pv := _label(p, Vector2(110, 38), 12)
		_info[cote] = {"nom": nom, "niv": niv, "rempli": rempli, "pv": pv}
	_boite = _panneau(Rect2(8, 236, 464, 76))
	add_child(_boite)
	_texte = _label(_boite, Vector2(12, 10), 15)
	_texte.size = Vector2(440, 56)
	_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fleche = _label(_boite, Vector2(440, 54), 12)
	_fleche.text = "v"
	_fleche.visible = false
	_menu_zone = _panneau(Rect2(236, 236, 236, 76))
	_menu_zone.visible = false
	add_child(_menu_zone)
	_attaques_zone = _panneau(Rect2(8, 236, 464, 76))
	_attaques_zone.visible = false
	add_child(_attaques_zone)

func _nom(p) -> String:
	return p.nom + (" ennemi" if ennemis.has(p) else "")

func _maj(cote: String, anime := true) -> void:
	var p = actif_j if cote == "j" else actif_e
	var i: Dictionary = _info[cote]
	i["nom"].text = p.nom.to_upper()
	i["niv"].text = "Nv%d" % p.niveau
	var part := float(p.pv) / float(p.stats["pv"])
	var cible := LARGEUR_BARRE * part
	i["rempli"].color = Color(0.2, 0.75, 0.3) if part > 0.5 else (Color(0.95, 0.8, 0.1) if part > 0.2 else Color(0.85, 0.2, 0.15))
	if cote == "j":
		i["pv"].text = "%d/ %d" % [maxi(p.pv, 0), p.stats["pv"]]
	if anime and not auto and is_inside_tree():
		create_tween().tween_property(i["rempli"], "size:x", cible, 0.5)
	else:
		i["rempli"].size.x = cible
	_sprite[cote].color = Color(String(Donnees.espece(p.espece_id).get("couleur", "#888888")))
	_sprite[cote].visible = p.pv > 0

# ---------- messages et menus ----------

func _pause(s: float) -> void:
	if not auto:
		await get_tree().create_timer(s).timeout

func _msg(t: String, attendre := true) -> void:
	journal.append(t)
	_menu_zone.visible = false
	_texte.size.x = 440
	_texte.text = t
	if auto or not attendre:
		return
	_fleche.visible = true
	while true:
		var n: String = await touche
		if n == "action":
			break
	_fleche.visible = false

# renvoie l'index choisi, ou -1 si annule
func _menu(options: Array, zone: Panel, colonnes: int, larg_col: int, annulable := false) -> int:
	if auto:
		return int(script_choix.pop_front()) if not script_choix.is_empty() else 0
	var labels: Array = []
	for c in zone.get_children():
		c.queue_free()
	for k in options.size():
		var l := _label(zone, Vector2(12 + (k % colonnes) * larg_col, 8 + (k / colonnes) * 28), 14)
		labels.append(l)
	zone.visible = true
	var i := 0
	while true:
		for k in labels.size():
			labels[k].text = ("> " if k == i else "  ") + String(options[k])
		var n: String = await touche
		match n:
			"haut": if i - colonnes >= 0: i -= colonnes
			"bas": if i + colonnes < options.size(): i += colonnes
			"gauche": if i % colonnes > 0: i -= 1
			"droite": if i % colonnes < colonnes - 1 and i + 1 < options.size(): i += 1
			"action":
				zone.visible = false
				return i
			"annuler":
				if annulable:
					zone.visible = false
					return -1
	return -1

# ---------- deroulement ----------

func _premier_vivant(liste: Array):
	for p in liste:
		if not p.ko():
			return p
	return null

# renvoie vrai si le joueur gagne
func combattre(eq: Array, en: Array, nom_dresseur := "Dresseur") -> bool:
	equipe = eq
	ennemis = en
	for p in equipe + ennemis:
		p.reinitialiser_stades()
	actif_j = _premier_vivant(equipe)
	actif_e = ennemis[0]
	en_cours = true
	visible = true
	_maj("j", false)
	_maj("e", false)
	await _msg("%s veut se battre !" % nom_dresseur.to_upper())
	await _msg("%s envoie %s !" % [nom_dresseur.to_upper(), actif_e.nom.to_upper()])
	await _msg("Go ! %s !" % actif_j.nom.to_upper())
	var victoire := false
	while true:
		var choix = await _choisir_action()
		var fin := await _tour(choix)
		if fin != 0:
			victoire = fin > 0
			break
	for p in equipe + ennemis:
		p.reinitialiser_stades()
	visible = false
	en_cours = false
	return victoire

# renvoie l'id de l'attaque choisie par le joueur
func _choisir_action() -> String:
	while true:
		_texte.size.x = 216
		_texte.text = "Que doit faire %s ?" % actif_j.nom.to_upper()
		var m := await _menu(["COMBAT", "SAC", "POKEMON", "FUITE"], _menu_zone, 2, 108)
		match m:
			1: await _msg("Le sac est vide pour l'instant.")
			2: await _msg("Tu ne peux pas encore changer de POKEMON.")
			3: await _msg("On ne s'enfuit pas d'un combat de dresseur !")
			_:
				var id := await _choisir_attaque()
				if id != "":
					return id
	return ""

func _choisir_attaque() -> String:
	var dispo := false
	for a in actif_j.attaques:
		if a["pp"] > 0:
			dispo = true
	if not dispo:
		await _msg("%s n'a plus de PP !" % actif_j.nom.to_upper())
		return "lutte"
	while true:
		var noms: Array = []
		for a in actif_j.attaques:
			noms.append("%s %d/%d" % [Donnees.attaque(a["id"]).get("nom", a["id"]), a["pp"], a["pp_max"]])
		var k := await _menu(noms, _attaques_zone, 2, 220, true)
		if k < 0:
			return ""
		if actif_j.attaques[k]["pp"] <= 0:
			await _msg("Plus de PP pour cette attaque !")
			continue
		return actif_j.attaques[k]["id"]
	return ""

func _choix_ia() -> String:
	var ok: Array = []
	for a in actif_e.attaques:
		if a["pp"] > 0:
			ok.append(a["id"])
	if ok.is_empty():
		return "lutte"
	return ok[rng.randi_range(0, ok.size() - 1)]

# un tour complet. Renvoie 0 (le combat continue), 1 (victoire) ou -1 (defaite)
func _tour(id_j: String) -> int:
	var id_e := _choix_ia()
	var j_d_abord := true
	var vj: int = actif_j.stat("vit")
	var ve: int = actif_e.stat("vit")
	if ve > vj or (ve == vj and rng.randi_range(0, 1) == 1):
		j_d_abord = false
	var ordre: Array = [[actif_j, actif_e, id_j], [actif_e, actif_j, id_e]]
	if not j_d_abord:
		ordre.reverse()
	for a in ordre:
		var att = a[0]
		var cib = a[1]
		if att.ko() or cib.ko():
			continue
		await _utiliser(att, cib, String(a[2]))
		if cib.ko():
			return await _apres_ko(cib)
	return 0

func _apres_ko(p) -> int:
	await _pause(0.3)
	await _msg("%s est K.O. !" % _nom(p).to_upper())
	if p == actif_e:
		if not actif_j.ko():
			var e: Dictionary = Donnees.espece(p.espece_id)
			var gain := int(floor(float(e.get("exp_base", 50)) * p.niveau / 7.0 * 1.5))
			await _msg("%s gagne %d points d'EXP !" % [actif_j.nom.to_upper(), gain])
			for m in actif_j.gagner_exp(gain):
				_maj("j", false)
				await _msg(String(m))
		var suivant = null
		for q in ennemis:
			if not q.ko():
				suivant = q
				break
		if suivant == null:
			await _msg("Tu as gagne le combat !")
			return 1
		actif_e = suivant
		actif_e.reinitialiser_stades()
		_maj("e", false)
		await _msg("L'adversaire envoie %s !" % actif_e.nom.to_upper())
		return 0
	# le Pokemon du joueur est K.O.
	var reste = _premier_vivant(equipe)
	if reste == null:
		await _msg("Tu n'as plus de POKEMON en etat de se battre !")
		await _msg("Tu as perdu le combat...")
		return -1
	actif_j = reste
	actif_j.reinitialiser_stades()
	_maj("j", false)
	await _msg("Go ! %s !" % actif_j.nom.to_upper())
	return 0

func _cote(p) -> String:
	return "j" if equipe.has(p) else "e"

func _utiliser(att, cib, id: String) -> void:
	var a: Dictionary = Donnees.attaque(id)
	for x in att.attaques:
		if x["id"] == id:
			x["pp"] = maxi(0, x["pp"] - 1)
	await _msg("%s utilise %s !" % [_nom(att).to_upper(), String(a.get("nom", id)).to_upper()], false)
	await _pause(0.6)
	if rng.randi_range(0, 99) >= int(a.get("precision", 100)):
		await _msg("L'attaque de %s rate !" % _nom(att).to_upper())
		return
	var puiss := int(a.get("puissance", 0))
	if puiss > 0:
		var eff := Donnees.efficacite(String(a["type"]), cib.types)
		if eff == 0.0:
			await _msg("Ca n'affecte pas %s..." % _nom(cib).to_upper())
			return
		var crit := rng.randi_range(0, 255) < int(Donnees.espece(att.espece_id).get("base", {}).get("vit", 50)) / 2
		var d := degats(att, cib, a, crit, eff)
		cib.pv = maxi(0, cib.pv - d)
		await _secouer(_cote(cib))
		_maj(_cote(cib))
		await _pause(0.6)
		if crit:
			await _msg("Coup critique !")
		if eff > 1.0:
			await _msg("C'est super efficace !")
		elif eff < 1.0:
			await _msg("Ce n'est pas tres efficace...")
		if a.has("effet") and not cib.ko():
			if rng.randf() < float(a["effet"].get("chance", 1.0)):
				await _effet(att, cib, a["effet"])
	elif a.has("effet"):
		await _effet(att, cib, a["effet"])
	else:
		await _msg("Mais rien ne se passe...")

# degats de la 1re generation (une partie aleatoire : 217..255 / 255)
func degats(att, cib, a: Dictionary, crit: bool, eff: float) -> int:
	var spec := Donnees.categorie_speciale(String(a["type"]))
	var A: int = att.stat("spe" if spec else "atk")
	var D: int = cib.stat("spe" if spec else "def")
	var niv: int = att.niveau * (2 if crit else 1)
	var d := int(floor(floor(floor(2.0 * niv / 5.0) + 2.0) * int(a["puissance"]) * A / D / 50.0)) + 2
	if att.types.has(a["type"]):
		d = int(floor(d * 1.5))
	d = int(floor(d * eff))
	d = int(floor(d * rng.randi_range(217, 255) / 255.0))
	return maxi(1, d)

const NOMS_STATS := {"atk": "L'ATTAQUE", "def": "La DEFENSE", "vit": "La VITESSE", "spe": "Le SPECIAL"}

func _effet(att, cib, e: Dictionary) -> void:
	var cible = att if String(e.get("cible", "adversaire")) == "soi" else cib
	var s := String(e["stat"])
	var n := int(e["stades"])
	var avant: int = cible.stades[s]
	var apres := clampi(avant + n, -6, 6)
	if apres == avant:
		await _msg("Rien ne se passe !")
		return
	cible.stades[s] = apres
	await _msg("%s de %s %s !" % [NOMS_STATS[s], _nom(cible).to_upper(), "monte" if n > 0 else "baisse"])

func _secouer(cote: String) -> void:
	if auto:
		return
	var s: ColorRect = _sprite[cote]
	var x := s.position.x
	var t := create_tween()
	for i in 3:
		t.tween_property(s, "position:x", x + 6, 0.04)
		t.tween_property(s, "position:x", x - 6, 0.04)
	t.tween_property(s, "position:x", x, 0.04)
	await t.finished
