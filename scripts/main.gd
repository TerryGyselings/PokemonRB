extends Node2D
# Scene principale : charge les cartes, gere les portes, les dialogues et la camera.

const Carte := preload("res://scripts/carte.gd")
const Joueur := preload("res://scripts/joueur.gd")
const Pnj := preload("res://scripts/pnj.gd")
const Evenements := preload("res://scripts/evenements.gd")
const Combat := preload("res://scripts/combat.gd")
const Pokemon := preload("res://scripts/pokemon.gd")

const CARTE_DEPART := "etage_joueur"   # le jeu commence dans ta chambre, a la case "depart" de la carte

var carte: Node2D
var joueur: Node2D
var camera: Camera2D
var voile: ColorRect
var boite: PanelContainer
var texte: Label
var _pages: Array = []
var _page := 0
var _transition := false
var drapeaux := {}            # avancement de l'histoire : nom -> true
var _pnj: Array = []
var _drapeau_apres_dialogue := ""
var evenement_en_cours := false
var evenements: RefCounted
var combat: CanvasLayer
var equipe: Array = []        # les Pokemon du joueur (6 maximum)
var _choix_panneau: Panel
var _choix_labels: Array = []
var _choix_index := 0
var _choix_actif := false
signal dialogue_fini
signal choix_fait(oui: bool)

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)
	_declarer_touches()

	carte = Carte.new()
	add_child(carte)
	joueur = Joueur.new()
	joueur.installer(self)
	joueur.z_index = 1
	add_child(joueur)
	joueur.arrive.connect(_sur_case_arrivee)

	evenements = Evenements.new()
	evenements.installer(self)

	camera = Camera2D.new()
	joueur.add_child(camera)
	camera.position = Vector2(8, 8)

	_creer_interface()
	combat = Combat.new()
	add_child(combat)
	charger_carte(CARTE_DEPART)

func _declarer_touches() -> void:
	_touche("haut", [KEY_UP, KEY_W, KEY_Z])
	_touche("bas", [KEY_DOWN, KEY_S])
	_touche("gauche", [KEY_LEFT, KEY_A, KEY_Q])
	_touche("droite", [KEY_RIGHT, KEY_D])
	_touche("action", [KEY_ENTER, KEY_SPACE, KEY_E])
	_touche("annuler", [KEY_X, KEY_BACKSPACE, KEY_ESCAPE])

func _touche(nom: String, touches: Array) -> void:
	if not InputMap.has_action(nom):
		InputMap.add_action(nom)
	for t in touches:
		var e := InputEventKey.new()
		e.physical_keycode = t
		InputMap.action_add_event(nom, e)

func _creer_interface() -> void:
	var couche := CanvasLayer.new()
	couche.layer = 10
	add_child(couche)
	voile = ColorRect.new()
	voile.color = Color.BLACK
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	voile.modulate.a = 0.0
	couche.add_child(voile)

	boite = PanelContainer.new()
	boite.anchor_left = 0.0
	boite.anchor_right = 1.0
	boite.anchor_top = 1.0
	boite.anchor_bottom = 1.0
	boite.offset_left = 8
	boite.offset_right = -8
	boite.offset_top = -64
	boite.offset_bottom = -8
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.97, 0.97, 0.92)
	style.border_color = Color.BLACK
	style.set_border_width_all(2)
	style.set_content_margin_all(8)
	boite.add_theme_stylebox_override("panel", style)
	texte = Label.new()
	texte.add_theme_color_override("font_color", Color.BLACK)
	texte.add_theme_font_size_override("font_size", 14)
	texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boite.add_child(texte)
	boite.visible = false
	couche.add_child(boite)

	_choix_panneau = Panel.new()
	_choix_panneau.anchor_left = 1.0
	_choix_panneau.anchor_right = 1.0
	_choix_panneau.anchor_top = 1.0
	_choix_panneau.anchor_bottom = 1.0
	_choix_panneau.offset_left = -108
	_choix_panneau.offset_right = -8
	_choix_panneau.offset_top = -124
	_choix_panneau.offset_bottom = -68
	_choix_panneau.add_theme_stylebox_override("panel", style)
	for i in 2:
		var l := Label.new()
		l.position = Vector2(12, 6 + i * 22)
		l.add_theme_color_override("font_color", Color.BLACK)
		l.add_theme_font_size_override("font_size", 14)
		_choix_panneau.add_child(l)
		_choix_labels.append(l)
	_choix_panneau.visible = false
	couche.add_child(_choix_panneau)

# ---------- cartes ----------

func charger_carte(id: String, arrivee = null) -> void:
	if not carte.charger(id):
		return
	var c: Vector2i = carte.depart if arrivee == null else arrivee
	joueur.placer(c)
	camera.limit_left = carte.origine.x * Carte.TAILLE
	camera.limit_top = carte.origine.y * Carte.TAILLE
	camera.limit_right = (carte.origine.x + carte.largeur) * Carte.TAILLE
	camera.limit_bottom = (carte.origine.y + carte.hauteur) * Carte.TAILLE
	camera.reset_smoothing()
	_creer_pnj()

# ---------- drapeaux et PNJ ----------

func poser_drapeau(nom: String) -> void:
	drapeaux[nom] = true
	_creer_pnj()

func a_drapeau(nom: String) -> bool:
	return bool(drapeaux.get(nom, false))

func _pnj_visible(d: Dictionary) -> bool:
	var v := String(d.get("visible_si", ""))
	var c := String(d.get("cache_si", ""))
	return (v == "" or a_drapeau(v)) and (c == "" or not a_drapeau(c))

func _creer_pnj() -> void:
	for p in _pnj:
		p.queue_free()
	_pnj.clear()
	for d in carte.pnj_donnees:
		if not _pnj_visible(d):
			continue
		if Vector2i(int(d["x"]), int(d["y"])) == joueur.case:
			continue   # ne jamais apparaitre sur le joueur
		var p := Pnj.new()
		p.installer(d)
		add_child(p)
		_pnj.append(p)

func pnj_a(c: Vector2i):
	for p in _pnj:
		if p.case == c:
			return p
	return null

# d = direction dans laquelle le joueur veut entrer sur la case c.
# Une porte avec "depuis" est infranchissable sauf si on arrive du bon cote.
func case_bloquee(c: Vector2i, d: Vector2i = Vector2i.ZERO) -> bool:
	if pnj_a(c) != null:
		return true
	var su: Vector2i = carte.sens_unique(c)
	if su != Vector2i.ZERO:      # rebord : on ne le franchit que dans son sens
		return d != su
	if carte.solide(c):
		return true
	var p: Dictionary = carte.porte(c)
	if p.is_empty():
		return false
	var sens: Vector2i = carte.sens_porte(p)
	return sens != Vector2i.ZERO and d != sens

# conditions "si" / "si_pas" (noms de drapeaux) d'une entree de JSON
func conditions_ok(d: Dictionary) -> bool:
	var si := String(d.get("si", ""))
	var si_pas := String(d.get("si_pas", ""))
	return (si == "" or a_drapeau(si)) and (si_pas == "" or not a_drapeau(si_pas))

func _sur_case_arrivee(c: Vector2i) -> void:
	if evenement_en_cours:
		return
	var p: Dictionary = carte.porte(c)
	if not p.is_empty():
		var sens: Vector2i = carte.sens_porte(p)
		if sens == Vector2i.ZERO or joueur.direction == sens:   # sinon : mauvais cote d'escalier
			_passer_porte(p)
			return
	for t in carte.declencheurs_en(c):
		if conditions_ok(t):
			evenements.jouer(String(t["evenement"]))
			return

func _passer_porte(p: Dictionary) -> void:
	joueur.bloque = true
	var a: Array = p.get("arrivee", [])
	await changer_carte(String(p["vers"]), Vector2i(int(a[0]), int(a[1])) if a.size() == 2 else null)
	joueur.bloque = false

# fondu au noir, changement de carte, fondu retour (a utiliser avec await)
func changer_carte(id: String, arrivee = null) -> void:
	_transition = true
	var t := create_tween()
	t.tween_property(voile, "modulate:a", 1.0, 0.15)
	await t.finished
	charger_carte(id, arrivee)
	t = create_tween()
	t.tween_property(voile, "modulate:a", 0.0, 0.15)
	await t.finished
	_transition = false

# plus court chemin (4 directions) en evitant les cases bloquees ; renvoie les cases a parcourir
# (sans la case de depart), ou [] s'il n'y en a pas. Le joueur est un obstacle sauf sur l'arrivee.
func chemin(depart: Vector2i, arrivee: Vector2i) -> Array:
	if depart == arrivee:
		return []
	var precedent := {depart: depart}
	var file: Array = [depart]
	while not file.is_empty():
		var c: Vector2i = file.pop_front()
		if c == arrivee:
			var res: Array = []
			while c != depart:
				res.push_front(c)
				c = precedent[c]
			return res
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if precedent.has(n):
				continue
			if n != arrivee and (case_bloquee(n) or n == joueur.case):
				continue
			if n == arrivee and (carte.solide(n) or pnj_a(n) != null):
				continue
			precedent[n] = c
			file.append(n)
	return []

# ---------- interactions et dialogues ----------

func _unhandled_input(event: InputEvent) -> void:
	if combat.en_cours:
		return
	if _choix_actif:
		if event.is_action_pressed("haut") or event.is_action_pressed("bas"):
			_choix_index = 1 - _choix_index
			_afficher_choix()
		elif event.is_action_pressed("action"):
			_choix_actif = false
			_choix_panneau.visible = false
			boite.visible = false
			choix_fait.emit(_choix_index == 0)
		elif event.is_action_pressed("annuler"):
			_choix_actif = false
			_choix_panneau.visible = false
			boite.visible = false
			choix_fait.emit(false)
		return
	if not event.is_action_pressed("action") or _transition:
		return
	if boite.visible:
		_page += 1
		if _page >= _pages.size():
			boite.visible = false
			joueur.bloque = evenement_en_cours
			if _drapeau_apres_dialogue != "":
				var nom := _drapeau_apres_dialogue
				_drapeau_apres_dialogue = ""
				poser_drapeau(nom)
			dialogue_fini.emit()
		else:
			texte.text = _pages[_page]
		return
	if joueur.en_marche() or evenement_en_cours:
		return
	var cible: Vector2i = joueur.case + joueur.direction
	var p = pnj_a(cible)
	if p != null:
		if not p.donnees.get("objet", false):
			p.tourner_vers(joueur.case)
		_parler(p.donnees)
		return
	var i: Dictionary = carte.interaction(cible)
	if not i.is_empty():
		_parler(i)

# une entree de JSON (PNJ ou interaction) : lance son evenement si les conditions sont bonnes, sinon son texte
func _parler(d: Dictionary) -> void:
	if d.has("evenement") and conditions_ok(d):
		evenements.jouer(String(d["evenement"]))
	else:
		dire(d.get("texte", []), String(d.get("pose", "")))

# pose une question OUI / NON et renvoie la reponse (a utiliser avec await)
func oui_non(question: String) -> bool:
	_pages = [question]
	_page = 0
	texte.text = question
	boite.visible = true
	joueur.bloque = true
	_choix_index = 0
	_afficher_choix()
	_choix_panneau.visible = true
	_choix_actif = true
	return await choix_fait

func _afficher_choix() -> void:
	_choix_labels[0].text = ("> " if _choix_index == 0 else "  ") + "OUI"
	_choix_labels[1].text = ("> " if _choix_index == 1 else "  ") + "NON"

func donner_pokemon(espece: String, niveau: int) -> void:
	equipe.append(Pokemon.creer(espece, niveau))

func dire(pages, drapeau := "") -> void:
	_pages = pages if pages is Array else [str(pages)]
	if _pages.is_empty():
		return
	_page = 0
	_drapeau_apres_dialogue = drapeau
	texte.text = _pages[0]
	boite.visible = true
	joueur.bloque = true

# affiche un dialogue et attend qu'il soit termine (a utiliser avec await)
func dire_attendre(pages, drapeau := "") -> void:
	dire(pages, drapeau)
	if boite.visible:
		await dialogue_fini
