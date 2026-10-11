extends Node2D
# Scene principale : charge les cartes, gere les portes, les dialogues et la camera.

const Carte := preload("res://scripts/carte.gd")
const Joueur := preload("res://scripts/joueur.gd")
const Pnj := preload("res://scripts/pnj.gd")
const Evenements := preload("res://scripts/evenements.gd")
const Combat := preload("res://scripts/combat.gd")
const Pokemon := preload("res://scripts/pokemon.gd")
const Donnees := preload("res://scripts/donnees.gd")
const Sauvegarde := preload("res://scripts/sauvegarde.gd")
const Titre := preload("res://scripts/titre.gd")
const Menu := preload("res://scripts/menu.gd")
const Boutique := preload("res://scripts/boutique.gd")
const PC := preload("res://scripts/pc.gd")

# les 8 badges (nom + couleur affichee dans la fiche du joueur)
const BADGES := [
	{"id": "roche", "nom": "Roche", "couleur": "#a0896a"}, {"id": "cascade", "nom": "Cascade", "couleur": "#4a90e2"},
	{"id": "foudre", "nom": "Foudre", "couleur": "#f2c230"}, {"id": "prisme", "nom": "Prisme", "couleur": "#6cc070"},
	{"id": "ame", "nom": "Ame", "couleur": "#b05ac0"}, {"id": "marais", "nom": "Marais", "couleur": "#e0709a"},
	{"id": "volcan", "nom": "Volcan", "couleur": "#e8553a"}, {"id": "terre", "nom": "Terre", "couleur": "#8b6a3a"}]

const POINT_SOIN_DEPART := {"carte": "maison_joueur", "arrivee": [4, 7]}   # avant le premier soin : la maison
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
var menu_jeu: CanvasLayer
var titre: CanvasLayer
var boutique: CanvasLayer
var pc: CanvasLayer
var avec_titre := false       # vrai quand le jeu est lance normalement (scene/lancement.tscn) ; faux dans les tests
var equipe: Array = []        # les Pokemon du joueur (6 maximum)
# etat de la partie (tout ca est sauvegarde)
var nom_joueur := "ROUGE"
var argent := 3000
var badges: Array = []        # ids des badges obtenus
var temps_jeu := 0.0          # secondes
var vus: Array = []           # especes vues (Pokedex)
var captures: Array = []      # especes capturees
var sac := {}                 # objet -> quantite
var point_soin := {}          # { "carte": id, "arrivee": [x, y] } : dernier endroit ou l'equipe a ete soignee
var slot_actuel := 0          # emplacement de sauvegarde de la partie en cours (1..3), 0 = aucun
var partie_en_cours := false
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
	combat.jeu = self
	add_child(combat)
	rng_rencontres.randomize()
	menu_jeu = Menu.new()
	menu_jeu.installer(self)
	add_child(menu_jeu)
	menu_jeu.quitter_demande.connect(func(): get_tree().quit())
	boutique = Boutique.new()
	boutique.installer(self)
	add_child(boutique)
	pc = PC.new()
	pc.installer(self)
	add_child(pc)
	if avec_titre:
		_demarrer()
	else:
		charger_carte(CARTE_DEPART)
		partie_en_cours = true

func _process(delta: float) -> void:
	if partie_en_cours:
		temps_jeu += delta
	# une touche de direction interrompt la marche automatique commandee a la souris
	if Input.is_action_pressed("haut") or Input.is_action_pressed("bas") or Input.is_action_pressed("gauche") or Input.is_action_pressed("droite"):
		_marche_auto += 1

# ---------- ecran titre, nouvelle partie, sauvegarde ----------

func _demarrer() -> void:
	partie_en_cours = false
	joueur.bloque = true
	titre = Titre.new()
	add_child(titre)
	var r: Dictionary = await titre.lancer()
	titre.queue_free()
	if String(r["mode"]) == "nouveau":
		nouvelle_partie(int(r["slot"]), String(r["nom"]))
	else:
		importer(r["donnees"], int(r["slot"]))
	joueur.bloque = false
	partie_en_cours = true

func nouvelle_partie(slot: int, nom: String) -> void:
	drapeaux = {}
	equipe = []
	argent = 3000
	badges = []
	temps_jeu = 0.0
	vus = []
	captures = []
	sac = {}
	_vider_boites()
	nom_joueur = nom
	slot_actuel = slot
	point_soin = POINT_SOIN_DEPART.duplicate(true)
	charger_carte(CARTE_DEPART)

func exporter() -> Dictionary:
	return {
		"nom": nom_joueur, "argent": argent, "badges": badges.duplicate(), "temps": temps_jeu,
		"drapeaux": drapeaux.duplicate(), "vus": vus.duplicate(), "captures": captures.duplicate(), "sac": sac.duplicate(),
		"equipe": equipe.map(func(p): return p.en_dictionnaire()),
		"boites": boites.map(func(b): return b.map(func(p): return p.en_dictionnaire() if p != null else {})),
		"point_soin": point_soin.duplicate(true), "carte": carte.id, "position": [joueur.case.x, joueur.case.y], "direction": [joueur.direction.x, joueur.direction.y],
	}

func importer(d: Dictionary, slot: int) -> void:
	nom_joueur = String(d.get("nom", "ROUGE"))
	argent = int(d.get("argent", 0))
	badges = Array(d.get("badges", []))
	temps_jeu = float(d.get("temps", 0.0))
	drapeaux = {}
	for k in d.get("drapeaux", {}):
		drapeaux[k] = bool(d["drapeaux"][k])
	vus = Array(d.get("vus", []))
	captures = Array(d.get("captures", []))
	sac = {}
	for k in d.get("sac", {}):
		sac[k] = int(d["sac"][k])
	equipe = []
	for pd in d.get("equipe", []):
		if not Donnees.espece(String(pd.get("espece", ""))).is_empty():
			equipe.append(Pokemon.depuis_dictionnaire(pd))
	_vider_boites()
	var sauvees: Array = d.get("boites", [])
	for b in mini(sauvees.size(), boites.size()):
		for i in mini(sauvees[b].size(), boites[b].size()):
			var pd: Dictionary = sauvees[b][i]
			if not pd.is_empty() and not Donnees.espece(String(pd.get("espece", ""))).is_empty():
				boites[b][i] = Pokemon.depuis_dictionnaire(pd)
	slot_actuel = slot
	point_soin = d.get("point_soin", POINT_SOIN_DEPART).duplicate(true)
	var pos: Array = d.get("position", [0, 0])
	var id := String(d.get("carte", CARTE_DEPART))
	if not carte.charger(id):
		id = CARTE_DEPART
	charger_carte(id, Vector2i(int(pos[0]), int(pos[1])) if d.has("position") else null)
	var dir: Array = d.get("direction", [0, 1])
	joueur.direction = Vector2i(int(dir[0]), int(dir[1]))
	joueur.queue_redraw()

# ---------- PC : boites de stockage ----------

var boites: Array = []        # boites[b][i] : un Pokemon ou null

func _vider_boites() -> void:
	boites = []
	for b in int(Donnees.regle("nb_boites", 14)):
		var l: Array = []
		l.resize(int(Donnees.regle("taille_boite", 30)))
		boites.append(l)

# premiere place libre en partant de la boite "depuis" (puis les suivantes) : Vector2i(boite, case), (-1, -1) si tout est plein
func place_libre_boite(depuis := 0) -> Vector2i:
	if boites.is_empty():
		_vider_boites()
	for k in boites.size():
		var b := (depuis + k) % boites.size()
		for i in boites[b].size():
			if boites[b][i] == null:
				return Vector2i(b, i)
	return Vector2i(-1, -1)

# donne un Pokemon au joueur : dans l'equipe s'il reste de la place, sinon dans une boite du PC
func recevoir_pokemon(p) -> Dictionary:
	enregistrer_capture(p.espece_id)
	if equipe.size() < int(Donnees.regle("taille_equipe", 6)):
		equipe.append(p)
		return {"ou": "equipe"}
	var pos := place_libre_boite()
	if pos.x < 0:
		return {"ou": "perdu"}
	boites[pos.x][pos.y] = p
	return {"ou": "boite", "boite": pos.x}

func enregistrer_vu(espece: String) -> void:
	if not vus.has(espece):
		vus.append(espece)

func enregistrer_capture(espece: String) -> void:
	enregistrer_vu(espece)
	if not captures.has(espece):
		captures.append(espece)

# tous les Pokemon sont K.O. : retour au dernier point de soin, equipe soignee
func blackout() -> void:
	var p: Dictionary = point_soin if not point_soin.is_empty() else POINT_SOIN_DEPART
	await dire_attendre(["${nom_joueur} n'a plus de POKEMON capable de se battre !", "${nom_joueur} s'evanouit..."])
	for pk in equipe:
		pk.soigner()
	var a: Array = p["arrivee"]
	await changer_carte(String(p["carte"]), Vector2i(int(a[0]), int(a[1])))
	joueur.direction = Vector2i.DOWN
	joueur.queue_redraw()
	await dire_attendre(["${nom_joueur} se reveille. Ses POKEMON ont ete soignes."])

func ouvrir_menu() -> void:
	joueur.bloque = true
	await menu_jeu.ouvrir()
	joueur.bloque = false

func _declarer_touches() -> void:
	_touche("haut", [KEY_UP, KEY_W, KEY_Z])
	_touche("bas", [KEY_DOWN, KEY_S])
	_touche("gauche", [KEY_LEFT, KEY_A, KEY_Q])
	_touche("droite", [KEY_RIGHT, KEY_D])
	_touche("action", [KEY_ENTER, KEY_SPACE, KEY_E])
	_touche("annuler", [KEY_X, KEY_BACKSPACE])
	_touche("menu", [KEY_TAB, KEY_M, KEY_ESCAPE])

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
	for k in drapeaux:        # arbustes deja coupes ("coupe@<carte>@x,y")
		if String(k).begins_with("coupe@") and drapeaux[k]:
			var parts: PackedStringArray = String(k).split("@")
			var xy: PackedStringArray = parts[2].split(",")
			carte.marquer_coupe(parts[1], Vector2i(int(xy[0]), int(xy[1])))
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
	_tester_rencontre(c)

# ---------- rencontres sauvages ----------

var rencontres_actives := true                 # false : tests / zone sure
var rng_rencontres := RandomNumberGenerator.new()

# chaque pas dans les hautes herbes (legende "rencontre") peut declencher un combat (data/rencontres.json : "taux" en % par pas)
func _tester_rencontre(c: Vector2i) -> bool:
	if not rencontres_actives or equipe.is_empty() or joueur.bloque:
		return false
	var type: String = carte.rencontre_a(c)
	if type == "":
		return false
	var table: Dictionary = Donnees.rencontres(carte.region_id_a(c), type)
	if table.is_empty() or rng_rencontres.randi_range(1, 100) > int(table.get("taux", 10)):
		return false
	var vivant := false
	for p in equipe:
		if not p.ko():
			vivant = true
	if not vivant:
		return false
	var tirage: Dictionary = Donnees.tirer_rencontre(table, rng_rencontres)
	if tirage.is_empty():
		return false
	lancer_rencontre(Pokemon.creer(String(tirage["espece"]), int(tirage["niveau"])))
	return true

# combat contre un Pokemon sauvage (fondu, combat, blackout si defaite) ; renvoie "victoire", "defaite", "fuite" ou "capture"
func lancer_rencontre(sauvage: Pokemon) -> String:
	joueur.bloque = true
	var t := create_tween()
	t.tween_property(voile, "modulate:a", 1.0, 0.3)
	await t.finished
	var fin: String = await combat.combat_sauvage(equipe, sauvage)
	voile.modulate.a = 0.0
	if fin == "defaite":
		await blackout()
	joueur.bloque = evenement_en_cours
	return fin

func _passer_porte(p: Dictionary) -> void:
	joueur.bloque = true
	var a: Array = p.get("arrivee", [])
	await changer_carte(String(p["vers"]), Vector2i(int(a[0]), int(a[1])) if a.size() == 2 else null)
	for e in carte.entrees:      # evenement d'entree de la carte (premier dont les conditions sont bonnes)
		if conditions_ok(e):
			await evenements.jouer(String(e["evenement"]))
			break
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

func _declencheur_actif(c: Vector2i) -> bool:
	for t in carte.declencheurs_en(c):
		if conditions_ok(t):
			return true
	return false

# plus court chemin (4 directions) en evitant les cases bloquees ; renvoie les cases a parcourir
# (sans la case de depart), ou [] s'il n'y en a pas. Le joueur est un obstacle sauf sur l'arrivee.
func chemin(depart: Vector2i, arrivee: Vector2i, eviter_portes := false) -> Array:
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
			if eviter_portes and (not carte.porte(n).is_empty() or _declencheur_actif(n)):
				continue   # marche automatique : on ne passe jamais par une porte ni par un declencheur d'evenement
			if n == arrivee and (carte.solide(n) or pnj_a(n) != null):
				continue
			precedent[n] = c
			file.append(n)
	return []

# ---------- interactions et dialogues ----------

func _unhandled_input(event: InputEvent) -> void:
	if combat.en_cours or boutique.actif or pc.actif:
		return
	if _choix_actif:
		if event.is_action_pressed("haut") or event.is_action_pressed("bas"):
			_choix_index = 1 - _choix_index
			_afficher_choix()
		elif event.is_action_pressed("action"):
			_valider_choix(_choix_index == 0)
		elif event.is_action_pressed("annuler"):
			_valider_choix(false)
		return
	if event.is_action_pressed("menu") and partie_en_cours and not _transition and not boite.visible \
			and not joueur.bloque and not joueur.en_marche() and not evenement_en_cours:
		ouvrir_menu()
		return
	if not event.is_action_pressed("action") or _transition:
		return
	if boite.visible:
		_avancer_dialogue()
		return
	if joueur.en_marche() or evenement_en_cours:
		return
	_interagir(joueur.case + joueur.direction)

# parle au PNJ / lit la pancarte / examine l'objet de la case "cible"
# (si c'est un comptoir vide, on parle "par-dessus" a ce qu'il y a juste derriere)
func _interagir(cible: Vector2i) -> void:
	var derriere: Vector2i = cible + joueur.direction
	if _est_comptoir_vide(cible) and _interactif(derriere):
		cible = derriere
	var p = pnj_a(cible)
	if p != null:
		if not p.donnees.get("objet", false):
			p.tourner_vers(joueur.case)
		_parler(p.donnees)
		return
	var i: Dictionary = carte.interaction(cible)
	if not i.is_empty():
		_parler(i)
		return
	if carte.est_coupable(cible):
		_couper(cible)

# qui peut utiliser COUPE ? (nom du Pokemon en majuscules, "" si personne)
# Un Pokemon de l'equipe qui connait l'attaque "coupe", ou le drapeau "capacite_coupe" (en attendant les CS).
func qui_coupe() -> String:
	for p in equipe:
		for a in p.attaques:
			if String(a["id"]) == "coupe":
				return String(p.nom).to_upper()
	if a_drapeau("capacite_coupe"):
		return String(equipe[0].nom).to_upper() if not equipe.is_empty() else nom_joueur.to_upper()
	return ""

func _couper(c: Vector2i) -> void:
	var nom := qui_coupe()
	if nom == "":
		dire(["Cet arbuste a l'air de pouvoir etre coupe !"])
		return
	if await oui_non("Cet arbuste peut etre coupe !\nUtiliser COUPE ?"):
		await dire_attendre(["%s utilise COUPE !" % nom])
		var l: Vector2i = carte.local_de(c)
		carte.couper(c)
		poser_drapeau("coupe@%s@%d,%d" % [carte.region_id_a(c), l.x, l.y])
	joueur.bloque = false

# case de comptoir (legende "pnj_ok") sur laquelle il n'y a rien : on peut parler par-dessus
func _est_comptoir_vide(c: Vector2i) -> bool:
	return carte.pnj_ok(c) and pnj_a(c) == null and carte.interaction(c).is_empty()

func _interactif_direct(c: Vector2i) -> bool:
	return pnj_a(c) != null or not carte.interaction(c).is_empty() or carte.est_coupable(c)

func _interactif(c: Vector2i) -> bool:
	if _interactif_direct(c):
		return true
	if _est_comptoir_vide(c):
		for d in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
			if pnj_a(c + d) != null or not carte.interaction(c + d).is_empty():
				return true
	return false

# ---------- souris dans le monde ----------

var _marche_auto := 0     # numero de la marche automatique en cours (changer ce numero l'annule)

# case du monde sous un point de l'ecran
func case_sous(pos: Vector2) -> Vector2i:
	var w: Vector2 = get_canvas_transform().affine_inverse() * pos
	return Vector2i(floori(w.x / Carte.TAILLE), floori(w.y / Carte.TAILLE))

func _monde_libre() -> bool:
	return partie_en_cours and not boite.visible and not _choix_actif and not _transition and not evenement_en_cours \
		and not joueur.bloque and not combat.en_cours and not menu_jeu.actif and not boutique.actif and not pc.actif

# clic sur un PNJ, une pancarte ou un objet : on se tourne vers lui (en marchant jusqu'a lui si besoin) et on interagit.
# Derriere un comptoir, cliquer sur le PNJ ou sur le comptoir revient au meme : on se place devant le comptoir.
func _clic_monde(c: Vector2i) -> void:
	if not _interactif(c) or joueur.en_marche():
		return
	var places: Array = []     # [ case ou se placer, direction a regarder, case visee ]
	if _interactif_direct(c):
		for d in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
			places.append([c + d, -d, c])
			var n: Vector2i = c + d       # comptoir juste devant : on se place de l'autre cote
			if _est_comptoir_vide(n):
				places.append([n + d, -d, c])
	else:     # clic sur le comptoir
		for d in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
			if pnj_a(c + d) != null or not carte.interaction(c + d).is_empty():
				places.append([c - d, d, c + d])
	_marche_auto += 1
	var mon := _marche_auto
	for pl in places:
		if pl[0] == joueur.case:
			joueur.direction = pl[1]
			joueur.queue_redraw()
			_interagir(joueur.case + joueur.direction)
			return
	var meilleur: Array = []
	var trouve := false
	var but: Array = []
	for pl in places:
		var v: Vector2i = pl[0]
		if carte.solide(v) or pnj_a(v) != null or not carte.dans_carte(v):
			continue
		var ch := chemin(joueur.case, v, true)
		if not ch.is_empty() and (not trouve or ch.size() < meilleur.size()):
			meilleur = ch
			trouve = true
			but = pl
	if not trouve:
		return
	for pas in meilleur:
		if mon != _marche_auto or not _monde_libre():
			return
		if not joueur.deplacer(pas - joueur.case):
			return
		await joueur.arrive
	if mon == _marche_auto and _monde_libre() and joueur.case == but[0]:
		joueur.direction = but[1]
		joueur.queue_redraw()
		_interagir(joueur.case + joueur.direction)

func _avancer_dialogue() -> void:
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

func _valider_choix(oui: bool) -> void:
	_choix_actif = false
	_choix_panneau.visible = false
	boite.visible = false
	choix_fait.emit(oui)

# zone cliquable de la ligne k (0 = OUI, 1 = NON) de la question OUI / NON
func rect_choix(k: int) -> Rect2:
	var r := _choix_panneau.get_global_rect()
	return Rect2(r.position + Vector2(4, 4 + k * 22), Vector2(r.size.x - 8, 22))

# souris dans le monde : un clic fait avancer un dialogue, survol / clic choisissent OUI ou NON
# (les menus, l'ecran titre et le combat gerent leur souris eux-memes)
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton or event is InputEventMouseMotion):
		return
	if combat.en_cours or menu_jeu.actif or boutique.actif or pc.actif or (is_instance_valid(titre) and titre.actif):
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		return
	if _choix_actif:
		var k := -1
		for j in 2:
			if rect_choix(j).has_point(event.position):
				k = j
		if event is InputEventMouseMotion:
			if k >= 0 and k != _choix_index:
				_choix_index = k
				_afficher_choix()
		elif event.pressed:
			get_viewport().set_input_as_handled()
			if event.button_index == MOUSE_BUTTON_LEFT and k >= 0:
				_choix_index = k
				_valider_choix(k == 0)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_valider_choix(false)
	elif boite.visible and not _transition and event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_avancer_dialogue()
	elif _monde_libre() or (partie_en_cours and joueur.en_marche() and not boite.visible):
		# le curseur devient une main au-dessus de ce avec quoi on peut interagir
		if event is InputEventMouseMotion:
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if _interactif(case_sous(event.position)) else Input.CURSOR_ARROW)
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _monde_libre():
			_clic_monde(case_sous(event.position))

# une entree de JSON (PNJ ou interaction) : lance son evenement si les conditions sont bonnes, sinon son texte
func _parler(d: Dictionary) -> void:
	if d.has("evenement") and conditions_ok(d):
		evenements.jouer(String(d["evenement"]))
	else:
		dire(d.get("texte", []), String(d.get("pose", "")))

# pose une question OUI / NON et renvoie la reponse (a utiliser avec await)
func oui_non(question: String) -> bool:
	question = remplacer_variables(question)
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

func donner_objet(id: String, quantite := 1) -> void:
	sac[id] = int(sac.get(id, 0)) + quantite

# retire jusqu'a "quantite" exemplaires ; renvoie vrai si le sac en contenait assez
func retirer_objet(id: String, quantite := 1) -> bool:
	var a := int(sac.get(id, 0))
	if a < quantite:
		return false
	if a == quantite:
		sac.erase(id)
	else:
		sac[id] = a - quantite
	return true

func donner_pokemon(espece: String, niveau: int) -> void:
	equipe.append(Pokemon.creer(espece, niveau))
	enregistrer_capture(espece)

# remplace les variables ecrites dans les textes des JSON : ${nom_joueur}, ${argent}
func remplacer_variables(t: String) -> String:
	return t.replace("${nom_joueur}", nom_joueur).replace("${argent}", str(argent))

# decoupe un texte trop long pour la boite de dialogue (2 lignes) en plusieurs pages, aux espaces
func _paginer(t: String) -> Array:
	var f: Font = texte.get_theme_font("font")
	var taille := 14
	var h := f.get_height(taille)
	var max_lignes := maxi(1, int(floor(40.0 / h)))
	var nb := func(x: String) -> int: return int(round(f.get_multiline_string_size(x, HORIZONTAL_ALIGNMENT_LEFT, 448.0, taille).y / h))
	var res: Array = []
	var cur := ""
	for m in t.split(" "):
		var essai: String = m if cur == "" else cur + " " + m
		if cur != "" and nb.call(essai) > max_lignes:
			res.append(cur)
			cur = m
		else:
			cur = essai
	res.append(cur)
	return res

func dire(pages, drapeau := "") -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_pages = []
	for t in (pages if pages is Array else [str(pages)]):
		_pages.append_array(_paginer(remplacer_variables(str(t))))
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
