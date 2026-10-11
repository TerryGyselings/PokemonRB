extends "res://scripts/ecran.gd"
# Le PC : stockage des Pokemon (14 boites de 30). Equipe a gauche, boite a droite.
# Clavier : fleches pour deplacer le curseur, Entree/Espace/E pour choisir, X/Echap pour sortir.
# Souris : survol + clic gauche, clic droit pour sortir.
# Utilisation : await pc.ouvrir()

const Donnees := preload("res://scripts/donnees.gd")

const COL := 6
const LIG := 5
const IDX_BOITE := 6             # index des cases de la boite dans la liste plate des zones (0..5 = equipe)
const IDX_PREC := 36
const IDX_SUIV := 37

var _jeu
var _boite_courante := 0
var _curseur := 6
var _deco: Control
var _liste: Control
var _entete: Label
var _details: Label
var _cadre: Panel
var _rects: Array = []

func installer(jeu) -> void:
	_jeu = jeu

func _ready() -> void:
	layer = 15
	visible = false
	var fond := ColorRect.new()
	fond.color = Color(0.88, 0.93, 0.96)
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)
	panneau(Rect2(8, 26, 150, 204))
	panneau(Rect2(164, 26, 308, 204))
	etiquette(self, Vector2(16, 6), 14, "EQUIPE")
	_entete = etiquette(self, Vector2(250, 6), 14)
	_deco = Control.new()
	add_child(_deco)
	_liste = Control.new()
	add_child(_liste)
	_cadre = Panel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(1, 1, 0.4, 0.25)
	st.border_color = Color(0.9, 0.2, 0.1)
	st.set_border_width_all(2)
	_cadre.add_theme_stylebox_override("panel", st)
	_cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cadre)
	var d := panneau(Rect2(8, 236, 464, 76))
	_details = etiquette(d, Vector2(10, 6), 13)
	_details.size = Vector2(444, 64)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# zones cliquables
	for i in 6:
		_rects.append(Rect2(12, 30 + i * 33, 142, 31))
	for i in COL * LIG:
		_rects.append(Rect2(170 + (i % COL) * 50, 52 + (i / COL) * 35, 48, 33))
	_rects.append(Rect2(168, 4, 70, 20))
	_rects.append(Rect2(398, 4, 70, 20))

# ---------- affichage ----------

func _equipe() -> Array:
	return _jeu.equipe

func _pokemon_a(k: int):
	if k < 6:
		return _equipe()[k] if k < _equipe().size() else null
	if k < IDX_PREC:
		return _jeu.boites[_boite_courante][k - IDX_BOITE]
	return null

func _dessiner() -> void:
	vider(_deco)
	vider(_liste)
	_entete.text = "<  BOITE %d / %d  >" % [_boite_courante + 1, _jeu.boites.size()]
	for k in IDX_PREC:
		var r: Rect2 = _rects[k]
		var p = _pokemon_a(k)
		var fond := ColorRect.new()
		fond.position = r.position
		fond.size = r.size
		fond.color = Color(0.93, 0.95, 0.9) if p != null else Color(0.82, 0.86, 0.84)
		_deco.add_child(fond)
		if p == null:
			continue
		var c := ColorRect.new()
		c.color = Color(p.couleur())
		c.position = r.position + Vector2(3, 3)
		c.size = Vector2(16, 16) if k < 6 else Vector2(18, 18)
		_deco.add_child(c)
		var etiq := etiquette(_liste, r.position + (Vector2(24, 0) if k < 6 else Vector2(2, 20)), 10)
		if k < 6:
			etiq.text = "%s%s Nv%d\nPV %d/%d" % ["*" if p.shiny else "", p.nom.to_upper().substr(0, 8), p.niveau, maxi(0, p.pv), p.stats["pv"]]
		else:
			etiq.text = ("*" if p.shiny else "") + p.nom.to_upper().substr(0, 6)
	_zones = _rects.duplicate()
	_placer_curseur()

func _placer_curseur() -> void:
	var r: Rect2 = _rects[_curseur]
	_cadre.position = r.position - Vector2(1, 1)
	_cadre.size = r.size + Vector2(2, 2)
	var p = _pokemon_a(_curseur)
	if p == null:
		_details.text = "" if _curseur < IDX_PREC else "Changer de BOITE"
		return
	var types: Array = p.types.map(func(t): return Donnees.nom_type(String(t)).to_upper())
	var genre: String = {"m": " M", "f": " F"}.get(p.genre, "")
	var att: Array = p.attaques.map(func(a): return String(Donnees.attaque(a["id"]).get("nom", a["id"])))
	_details.text = "%s%s%s  Nv%d   %s   PV %d/%d\nNature %s  Talent %s\n%s" % ["*" if p.shiny else "", p.nom.to_upper(), genre, p.niveau, "/".join(types),
		maxi(0, p.pv), p.stats["pv"], String(Donnees.nature(p.nature).get("nom", p.nature)), String(Donnees.talent(p.talent).get("nom", p.talent)), ", ".join(att)]

# ---------- deplacement du curseur ----------

func _deplacer(dir: String) -> void:
	var k := _curseur
	if k < 6:
		match dir:
			"haut": k = maxi(0, k - 1)
			"bas": k = mini(5, k + 1)
			"droite": k = IDX_BOITE + mini(k, LIG - 1) * COL
	elif k < IDX_PREC:
		var i := k - IDX_BOITE
		var l := i / COL
		var c := i % COL
		match dir:
			"gauche": k = (l if c == 0 else IDX_BOITE + i - 1) if c > 0 else l
			"droite": k = k + 1 if c < COL - 1 else k
			"haut": k = (IDX_BOITE + i - COL) if l > 0 else (IDX_PREC if c < 3 else IDX_SUIV)
			"bas": k = (IDX_BOITE + i + COL) if l < LIG - 1 else k
	else:
		match dir:
			"gauche": k = IDX_PREC
			"droite": k = IDX_SUIV
			"bas": k = IDX_BOITE if k == IDX_PREC else IDX_BOITE + COL - 1
	if k != _curseur:
		_curseur = k
		_placer_curseur()

func _changer_boite(delta: int) -> void:
	var n: int = _jeu.boites.size()
	_boite_courante = (_boite_courante + delta + n) % n
	_dessiner()

# ---------- actions ----------

func ouvrir() -> void:
	_boite_courante = 0
	_curseur = IDX_BOITE
	visible = true
	actif = true
	_dessiner()
	while true:
		var n: String = await touche
		if n == "annuler" or n == "menu":
			break
		if n in ["haut", "bas", "gauche", "droite"]:
			_deplacer(n)
		elif n.begins_with("survol:"):
			_curseur = int(n.substr(7))
			_placer_curseur()
		elif n == "action" or n.begins_with("clic:"):
			if n.begins_with("clic:"):
				_curseur = int(n.substr(5))
				_placer_curseur()
			await _activer(_curseur)
	visible = false
	actif = false
	effacer_zones()

func _activer(k: int) -> void:
	if k == IDX_PREC:
		_changer_boite(-1)
		return
	if k == IDX_SUIV:
		_changer_boite(1)
		return
	var p = _pokemon_a(k)
	if p == null:
		return
	var options: Array = ["DEPOSER", "ANNULER"] if k < 6 else ["RETIRER", "RELACHER", "ANNULER"]
	var zone := panneau(Rect2(340, 150, 128, 28 + options.size() * 24))
	var choix: int = await choisir(options, zone, 1, 112, 24, true, Vector2(10, 8))
	zone.queue_free()
	_zones = _rects.duplicate()
	match String(options[choix]) if choix >= 0 else "ANNULER":
		"DEPOSER": await _deposer(k)
		"RETIRER": await _retirer(k - IDX_BOITE)
		"RELACHER": await _relacher(k - IDX_BOITE)
	_dessiner()

func _msg(t: String) -> void:
	effacer_zones()
	await message(t, self)
	_zones = _rects.duplicate()

func _deposer(k: int) -> void:
	var p = _equipe()[k]
	var autres_valides := 0
	for q in _equipe():
		if q != p and not q.ko():
			autres_valides += 1
	if autres_valides == 0:
		await _msg("Il faut garder au moins un POKEMON en etat de se battre !")
		return
	var pos: Vector2i = _jeu.place_libre_boite(_boite_courante)
	if pos.x < 0:
		await _msg("Les boites du PC sont pleines !")
		return
	_jeu.boites[pos.x][pos.y] = p
	_equipe().remove_at(k)
	if _curseur < 6:
		_curseur = mini(_curseur, maxi(0, _equipe().size() - 1))
	await _msg("%s a ete depose dans la BOITE %d." % [p.nom.to_upper(), pos.x + 1])

func _retirer(i: int) -> void:
	if _equipe().size() >= int(Donnees.regle("taille_equipe", 6)):
		await _msg("Ton equipe est deja pleine !")
		return
	var p = _jeu.boites[_boite_courante][i]
	_jeu.boites[_boite_courante][i] = null
	_equipe().append(p)
	await _msg("%s a ete retire de la boite." % p.nom.to_upper())

func _relacher(i: int) -> void:
	var p = _jeu.boites[_boite_courante][i]
	if not await oui_non("Relacher %s ? Cette action est definitive." % p.nom.to_upper(), self):
		_zones = _rects.duplicate()
		return
	_zones = _rects.duplicate()
	_jeu.boites[_boite_courante][i] = null
	await _msg("Au revoir, %s !" % p.nom.to_upper())
