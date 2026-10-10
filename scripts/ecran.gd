extends CanvasLayer
# Base des ecrans plein ecran (titre, menu...) : lecture des touches, panneaux, listes a curseur, messages, OUI/NON.
# Les ecrans s'utilisent avec await (ex : var choix = await ecran.lancer()).

signal touche(nom: String)
signal clavier(evenement: InputEventKey)   # lettres tapees (saisie du nom)

const TOUCHES := ["action", "annuler", "haut", "bas", "gauche", "droite", "menu"]

var actif := false
var _zones: Array = []     # rectangles (ecran) des lignes cliquables de la liste en cours
var _survol := -1

# Clavier ET souris :
#   fleches / Entree / Echap  ou  survol / clic gauche / clic droit / molette
# La souris est traduite en "touches" : "survol:N" et "clic:N" (N = ligne de la liste), "action" (clic gauche hors
# liste, quand aucune liste n'est affichee : fait avancer un message), "annuler" (clic droit), "haut" / "bas" (molette).
func _input(event: InputEvent) -> void:
	if not actif:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		clavier.emit(event)
	if event is InputEventMouseMotion:
		var k := _ligne_a(event.position)
		if k >= 0 and k != _survol:
			_survol = k
			touche.emit("survol:%d" % k)
		elif k < 0:
			_survol = -1
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				get_viewport().set_input_as_handled()
				var k := _ligne_a(event.position)
				if k >= 0:
					touche.emit("clic:%d" % k)
				elif _zones.is_empty():
					touche.emit("action")
			MOUSE_BUTTON_RIGHT:
				get_viewport().set_input_as_handled()
				touche.emit("annuler")
			MOUSE_BUTTON_WHEEL_UP:
				get_viewport().set_input_as_handled()
				touche.emit("haut")
			MOUSE_BUTTON_WHEEL_DOWN:
				get_viewport().set_input_as_handled()
				touche.emit("bas")
		return
	for nom in TOUCHES:
		if event.is_action_pressed(nom):
			get_viewport().set_input_as_handled()
			touche.emit(nom)
			return

func _ligne_a(pos: Vector2) -> int:
	for k in _zones.size():
		if _zones[k].has_point(pos):
			return k
	return -1

# declare les lignes cliquables d'une liste (memes parametres que choisir)
func enregistrer_zones(zone: Control, n: int, colonnes: int, larg_col: int, haut_ligne: int, depart: Vector2) -> void:
	_zones.clear()
	_survol = -1
	var o := zone.get_global_rect().position + depart + Vector2(-4, -2)
	for k in n:
		_zones.append(Rect2(o + Vector2((k % colonnes) * larg_col, (k / colonnes) * haut_ligne), Vector2(larg_col, haut_ligne)))

func effacer_zones() -> void:
	_zones.clear()
	_survol = -1

# centre de la ligne k de la liste en cours (pour les tests)
func centre_ligne(k: int) -> Vector2:
	return _zones[k].get_center()

# pour les tests : simule l'appui sur une touche
func appuyer(nom: String) -> void:
	touche.emit(nom)

func panneau(r: Rect2, parent: Node = null) -> Panel:
	var p := Panel.new()
	p.position = r.position
	p.size = r.size
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.97, 0.97, 0.92)
	s.border_color = Color.BLACK
	s.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", s)
	(parent if parent != null else self).add_child(p)
	return p

func etiquette(parent: Node, pos: Vector2, taille := 14, texte := "") -> Label:
	var l := Label.new()
	l.position = pos
	l.text = texte
	l.add_theme_color_override("font_color", Color.BLACK)
	l.add_theme_font_size_override("font_size", taille)
	parent.add_child(l)
	return l

func vider(zone: Node) -> void:
	for c in zone.get_children():
		zone.remove_child(c)
		c.queue_free()

# Liste a curseur dans "zone". Renvoie l'index choisi, ou -1 si annule.
# actifs (optionnel) : booleens, les options inactives sont grisees et non validables.
# fenetre : nombre de lignes visibles (liste verticale qui defile), 0 = tout afficher.
func choisir(options: Array, zone: Control, colonnes := 1, larg_col := 200, haut_ligne := 24, annulable := true,
		depart := Vector2(12, 8), actifs: Array = [], index_depart := 0, fenetre := 0) -> int:
	vider(zone)
	var visibles := options.size() if fenetre <= 0 or colonnes > 1 else mini(fenetre, options.size())
	var labels: Array = []
	for k in visibles:
		labels.append(etiquette(zone, depart + Vector2((k % colonnes) * larg_col, (k / colonnes) * haut_ligne)))
	enregistrer_zones(zone, visibles, colonnes, larg_col, haut_ligne, depart)
	var i := clampi(index_depart, 0, maxi(options.size() - 1, 0))
	var debut := 0
	var res := -2
	while res == -2:
		if i < debut:
			debut = i
		if i >= debut + visibles:
			debut = i - visibles + 1
		for k in labels.size():
			var idx: int = debut + k
			labels[k].text = ("> " if idx == i else "  ") + String(options[idx])
			var grise: bool = actifs.size() > idx and not actifs[idx]
			labels[k].add_theme_color_override("font_color", Color(0.55, 0.55, 0.55) if grise else Color.BLACK)
		var n: String = await touche
		if n.begins_with("survol:") or n.begins_with("clic:"):
			var idx: int = debut + int(n.substr(n.find(":") + 1))
			if idx < options.size():
				i = idx
				if n.begins_with("clic:") and (actifs.size() <= i or actifs[i]):
					res = i
			continue
		match n:
			"haut": if i - colonnes >= 0: i -= colonnes
			"bas": if i + colonnes < options.size(): i += colonnes
			"gauche": if i % colonnes > 0: i -= 1
			"droite": if i % colonnes < colonnes - 1 and i + 1 < options.size(): i += 1
			"action":
				if i < options.size() and (actifs.size() <= i or actifs[i]):
					res = i
			"annuler", "menu":
				if annulable:
					res = -1
	effacer_zones()
	return res

# boite de texte en bas de l'ecran ; attend "action"
func message(texte: String, parent: Node = null) -> void:
	var b := panneau(Rect2(8, 236, 464, 76), parent)
	var l := etiquette(b, Vector2(12, 10), 15, texte)
	l.size = Vector2(440, 56)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	while true:
		var n: String = await touche
		if n == "action" or n == "annuler":
			break
	b.queue_free()

# question OUI / NON en bas de l'ecran
func oui_non(texte: String, parent: Node = null) -> bool:
	var b := panneau(Rect2(8, 236, 464, 76), parent)
	var l := etiquette(b, Vector2(12, 10), 15, texte)
	l.size = Vector2(300, 56)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var z := panneau(Rect2(340, 160, 120, 62), parent)
	var r: int = await choisir(["OUI", "NON"], z, 1, 100, 26, true, Vector2(14, 6))
	b.queue_free()
	z.queue_free()
	return r == 0
