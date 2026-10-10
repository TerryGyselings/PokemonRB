extends "res://scripts/ecran.gd"
# Ecran titre : petite animation, "appuie sur un bouton", puis CONTINUER / NOUVELLE PARTIE avec trois emplacements.
# lancer() renvoie { "mode": "nouveau", "slot": 1..3, "nom": "ROUGE" } ou { "mode": "continuer", "slot": n, "donnees": {...} }

const Donnees := preload("res://scripts/donnees.gd")
const Sauvegarde := preload("res://scripts/sauvegarde.gd")
const NOM_PAR_DEFAUT := "ROUGE"
const NOM_MAX := 8

var _racine: Control
var _invite: Label
var _anim: Array = []      # tweens a arreter quand on quitte l'ecran d'accueil

func lancer() -> Dictionary:
	layer = 30
	actif = true
	var fond := ColorRect.new()
	fond.color = Color(0.05, 0.07, 0.2)
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)
	_racine = Control.new()
	_racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_racine)
	while true:
		_ecran_accueil()
		while true:
			var n: String = await touche
			if n == "action":
				break
		_arreter_anim()
		vider(_racine)
		var res := await _menu_principal()
		if not res.is_empty():
			actif = false
			return res
	return {}

func _arreter_anim() -> void:
	for t in _anim:
		if t != null and t.is_valid():
			t.kill()
	_anim.clear()

# ---------- animation ----------

func _ecran_accueil() -> void:
	# bandes de fond qui defilent
	for k in 6:
		var b := ColorRect.new()
		b.color = Color(0.1, 0.13, 0.32, 0.55)
		b.size = Vector2(500, 18)
		b.position = Vector2(-20, 20 + k * 54)
		_racine.add_child(b)
		var t := create_tween().set_loops()
		t.tween_property(b, "position:x", -20.0 + (14 if k % 2 == 0 else -14), 2.0 + k * 0.2).set_trans(Tween.TRANS_SINE)
		t.tween_property(b, "position:x", -20.0, 2.0 + k * 0.2).set_trans(Tween.TRANS_SINE)
		_anim.append(t)
	# titre : tombe du haut et rebondit
	var titre := _gros_texte("POKéMON", 56, Color("#ffcb05"), Color("#2a4b9b"))
	titre.position = Vector2(0, -90)
	titre.size = Vector2(480, 70)
	_racine.add_child(titre)
	var t1 := create_tween()
	t1.tween_property(titre, "position:y", 26.0, 1.1).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_anim.append(t1)
	var version := _gros_texte("Version Rouge / Bleu", 18, Color.WHITE, Color.BLACK)
	version.size = Vector2(480, 26)
	version.position = Vector2(500, 100)
	_racine.add_child(version)
	var t2 := create_tween()
	t2.tween_interval(0.8)
	t2.tween_property(version, "position:x", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim.append(t2)
	# le "Pokemon" central change d'espece en fondu, avec un petit rebond
	var ids: Array = Donnees.toutes_les_especes()
	var centre := ColorRect.new()
	centre.size = Vector2(88, 88)
	centre.position = Vector2(196, 142)
	centre.pivot_offset = Vector2(44, 44)
	centre.scale = Vector2.ZERO
	_racine.add_child(centre)
	var t3 := create_tween().set_loops()
	for id in ids:
		t3.tween_callback(func():
			centre.color = Color(String(Donnees.espece(id).get("couleur", "#888888"))))
		t3.tween_property(centre, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t3.tween_property(centre, "position:y", 132.0, 0.35).set_trans(Tween.TRANS_SINE)
		t3.tween_property(centre, "position:y", 142.0, 0.35).set_trans(Tween.TRANS_SINE)
		t3.tween_interval(0.5)
		t3.tween_property(centre, "scale", Vector2.ZERO, 0.25)
	_anim.append(t3)
	# invite clignotante
	_invite = _gros_texte("- Appuie sur Entrée -", 16, Color.WHITE, Color.BLACK)
	_invite.size = Vector2(480, 24)
	_invite.position = Vector2(0, 268)
	_racine.add_child(_invite)
	var t4 := create_tween().set_loops()
	t4.tween_property(_invite, "modulate:a", 0.15, 0.6)
	t4.tween_property(_invite, "modulate:a", 1.0, 0.6)
	_anim.append(t4)

func _gros_texte(texte: String, taille: int, couleur: Color, contour: Color) -> Label:
	var l := Label.new()
	l.text = texte
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_color_override("font_outline_color", contour)
	l.add_theme_constant_override("outline_size", maxi(3, taille / 6))
	return l

# ---------- menus ----------

func _menu_principal() -> Dictionary:
	var une_sauvegarde := false
	for s in range(1, Sauvegarde.NB_SLOTS + 1):
		if Sauvegarde.existe(s):
			une_sauvegarde = true
	while true:
		var zone := panneau(Rect2(120, 90, 240, 100), _racine)
		var r: int = await choisir(["CONTINUER", "NOUVELLE PARTIE"], zone, 1, 200, 34, true, Vector2(24, 16), [une_sauvegarde, true], 0 if une_sauvegarde else 1)
		zone.queue_free()
		if r < 0:
			return {}
		if r == 0:
			var s := await _choisir_slot(true)
			if s > 0:
				return {"mode": "continuer", "slot": s, "donnees": Sauvegarde.lire(s)}
		else:
			var s := await _choisir_slot(false)
			if s > 0:
				if Sauvegarde.existe(s) and not await oui_non("L'emplacement %d contient déjà une partie.\nL'écraser ?" % s, _racine):
					continue
				var nom := await _saisir_nom()
				return {"mode": "nouveau", "slot": s, "nom": nom}
	return {}

# renvoie 1..3, ou 0 si annule
func _choisir_slot(pour_continuer: bool) -> int:
	var zone := panneau(Rect2(30, 40, 420, 190), _racine)
	var textes: Array = []
	var actifs: Array = []
	for s in range(1, Sauvegarde.NB_SLOTS + 1):
		textes.append("EMPLACEMENT %d\n      %s" % [s, Sauvegarde.resume(s)])
		actifs.append(Sauvegarde.existe(s) or not pour_continuer)
	var premier := 0
	if pour_continuer:
		for k in actifs.size():
			if actifs[k]:
				premier = k
				break
	var r: int = await choisir(textes, zone, 1, 400, 56, true, Vector2(18, 10), actifs, premier)
	zone.queue_free()
	return r + 1 if r >= 0 else 0

func _saisir_nom() -> String:
	var z := panneau(Rect2(50, 80, 380, 130), _racine)
	etiquette(z, Vector2(18, 12), 17, "COMMENT T'APPELLES-TU ?")
	var champ := etiquette(z, Vector2(18, 48), 30)
	etiquette(z, Vector2(18, 100), 11, "Tape ton nom (%d lettres max), puis Entrée" % NOM_MAX)
	var nom := ""
	while true:
		champ.text = nom + "_"
		var e: InputEventKey = await clavier
		if e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER:
			break
		elif e.keycode == KEY_BACKSPACE:
			nom = nom.left(maxi(0, nom.length() - 1))
		elif e.unicode > 32 or e.unicode == 32:
			var c := char(e.unicode)
			var ok := c.to_lower() != c.to_upper() or c.is_valid_int() or c == "-" or c == " " or c == "."
			if ok and nom.length() < NOM_MAX:
				nom += c.to_upper()
	z.queue_free()
	nom = nom.strip_edges()
	return NOM_PAR_DEFAUT if nom == "" else nom
