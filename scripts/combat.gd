extends "res://scripts/ecran.gd"
# Ecran de combat (Pokemon sauvage ou dresseur). L'ecran ne contient AUCUNE regle : il lit les choix du joueur,
# les donne au moteur (scripts/bataille.gd) puis rejoue les evenements que le moteur produit.
#
#   var victoire: bool = await combat.combattre(equipe, ennemis, "RIVAL")            # dresseur
#   var fin: String   = await combat.combat_sauvage(equipe, pokemon)                  # "victoire" "defaite" "fuite" "capture"
#
# Touches : fleches / souris pour le curseur, Entree-Espace-E pour valider, X-Retour arriere (ou clic droit) pour annuler.

const Donnees := preload("res://scripts/donnees.gd")
const Pokemon := preload("res://scripts/pokemon.gd")
const Bataille := preload("res://scripts/bataille.gd")
const LARGEUR_BARRE := 110.0
const COULEURS_STATUT := {"paralysie": ["PAR", Color(0.9, 0.75, 0.1)], "brulure": ["BRU", Color(0.9, 0.4, 0.15)],
	"poison": ["PSN", Color(0.6, 0.3, 0.75)], "poison_grave": ["PSN", Color(0.45, 0.2, 0.6)],
	"sommeil": ["SOM", Color(0.5, 0.5, 0.55)], "gel": ["GEL", Color(0.35, 0.75, 0.9)]}

var jeu                           # main.gd (sac, Pokedex) ; null dans les tests
var auto := false                 # tests : pas d'attente, choix lus dans script_choix (0 par defaut)
var script_choix: Array = []
var rng := RandomNumberGenerator.new()
var journal: Array = []           # tous les messages affiches (utile pour les tests)
var equipe: Array = []
var ennemis: Array = []
var bat                           # moteur en cours (Bataille)
var en_cours := false
var actif_j:
	get: return bat.actif["j"] if bat != null else null
var actif_e:
	get: return bat.actif["e"] if bat != null else null

var _fond: ColorRect
var _sprite := {}                 # "j" / "e" -> ColorRect
var _info := {}                   # "j" / "e" -> { nom, niv, rempli, pv, exp, statut }
var _panneaux := {}               # "j" / "e" -> panneau d'information
var _boite: Panel
var _texte: Label
var _menu_zone: Panel
var _attaques_zone: Panel
var _fleche: Label
var _liste_zone: Panel

func _ready() -> void:
	layer = 20
	visible = false
	rng.randomize()
	_construire()

# ---------- construction de l'ecran ----------

func _panneau(r: Rect2) -> Panel:
	return panneau(r)

func _label(parent: Node, pos: Vector2, taille := 13) -> Label:
	return etiquette(parent, pos, taille)

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
		var p := _panneau(Rect2(12, 12, 230, 56) if cote == "e" else Rect2(246, 140, 224, 76))
		_panneaux[cote] = p
		var nom := _label(p, Vector2(8, 2))
		var niv := _label(p, Vector2(160, 2))
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
		var st := _label(p, Vector2(8, 38), 11)
		var pv := _label(p, Vector2(110, 38), 12)
		var exp_fond := ColorRect.new()
		exp_fond.color = Color(0.25, 0.25, 0.25)
		exp_fond.position = Vector2(8, 62)
		exp_fond.size = Vector2(208, 6)
		p.add_child(exp_fond)
		var exp_r := ColorRect.new()
		exp_r.color = Color(0.3, 0.55, 0.95)
		exp_r.position = Vector2(1, 1)
		exp_r.size = Vector2(0, 4)
		exp_fond.add_child(exp_r)
		exp_fond.visible = cote == "j"
		_info[cote] = {"nom": nom, "niv": niv, "rempli": rempli, "pv": pv, "exp": exp_r, "statut": st}
	_boite = _panneau(Rect2(8, 236, 464, 76))
	_texte = _label(_boite, Vector2(12, 10), 15)
	_texte.size = Vector2(440, 56)
	_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fleche = _label(_boite, Vector2(440, 54), 12)
	_fleche.text = "v"
	_fleche.visible = false
	_menu_zone = _panneau(Rect2(236, 236, 236, 76))
	_menu_zone.visible = false
	_attaques_zone = _panneau(Rect2(8, 236, 464, 76))
	_attaques_zone.visible = false
	_liste_zone = _panneau(Rect2(8, 8, 464, 224))
	_liste_zone.visible = false

# ---------- affichage des Pokemon ----------

func _snap(p) -> Dictionary:
	return {"nom": p.nom, "niveau": p.niveau, "pv": maxi(0, p.pv), "pv_max": p.stats["pv"], "statut": p.statut, "couleur": p.couleur(),
		"shiny": p.shiny, "genre": p.genre, "espece": p.espece_id, "exp": p.exp, "exp_min": p.exp_seuil(p.niveau), "exp_max": p.exp_seuil(p.niveau + 1)}

func _maj_p(cote: String, p, anime := true) -> void:
	_appliquer(cote, _snap(p), anime)

# met a jour le panneau et le sprite d'un cote ; renvoie la duree de l'animation de la barre
func _appliquer(cote: String, e: Dictionary, anime := true) -> float:
	var i: Dictionary = _info[cote]
	var genre: String = {"m": " M", "f": " F"}.get(String(e["genre"]), "")
	i["nom"].text = ("*" if e["shiny"] else "") + String(e["nom"]).to_upper() + genre
	i["niv"].text = "Nv%d" % int(e["niveau"])
	var part: float = float(e["pv"]) / float(maxi(1, int(e["pv_max"])))
	var cible := LARGEUR_BARRE * part
	i["rempli"].color = Color(0.2, 0.75, 0.3) if part > 0.5 else (Color(0.95, 0.8, 0.1) if part > 0.2 else Color(0.85, 0.2, 0.15))
	if cote == "j":
		i["pv"].text = "%d/ %d" % [int(e["pv"]), int(e["pv_max"])]
	var st = COULEURS_STATUT.get(String(e["statut"]))
	i["statut"].text = st[0] if st != null else ""
	i["statut"].add_theme_color_override("font_color", st[1] if st != null else Color.BLACK)
	var duree := 0.0
	if anime and not auto and is_inside_tree() and absf(i["rempli"].size.x - cible) > 0.5:
		duree = 0.5
		create_tween().tween_property(i["rempli"], "size:x", cible, duree)
	else:
		i["rempli"].size.x = cible
	if cote == "j":
		# barre d'EXP : se remplit en douceur ; a la montee de niveau elle va au bout puis repart de zero
		var span := float(maxi(1, int(e["exp_max"]) - int(e["exp_min"])))
		var cible_exp: float = clampf((float(e["exp"]) - float(e["exp_min"])) / span, 0.0, 1.0) * 206.0
		var barre: ColorRect = i["exp"]
		var niv_aff: int = int(i.get("niv_val", int(e["niveau"])))
		var monte: bool = int(e["niveau"]) > niv_aff
		if anime and not auto and is_inside_tree() and (monte or absf(barre.size.x - cible_exp) > 0.5):
			var t := create_tween()
			if monte:
				t.tween_property(barre, "size:x", 206.0, 0.6)
				t.tween_callback(func(): barre.size.x = 0.0)
				t.tween_property(barre, "size:x", cible_exp, 0.4)
				duree = maxf(duree, 1.0)
			else:
				t.tween_property(barre, "size:x", cible_exp, 0.7)
				duree = maxf(duree, 0.7)
		else:
			barre.size.x = cible_exp
		i["niv_val"] = int(e["niveau"])
	_sprite[cote].color = Color(String(e["couleur"]))
	# un Pokemon a 0 PV garde son sprite tant que la barre descend : c'est _jouer() qui le cache ensuite
	if int(e["pv"]) > 0:
		_sprite[cote].visible = true
	elif not anime or auto:
		_sprite[cote].visible = false
	_panneaux[cote].visible = true
	_panneaux[cote].get_theme_stylebox("panel").border_color = Color(0.85, 0.65, 0.1) if e["shiny"] else Color.BLACK
	return duree

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

# renvoie l'index choisi, ou -1 si annule (clavier et souris : voir ecran.gd)
func _menu(options: Array, zone: Panel, colonnes: int, larg_col: int, annulable := false, actifs: Array = [], hauteur := 28) -> int:
	if auto:
		var r: int = int(script_choix.pop_front()) if not script_choix.is_empty() else 0
		return r if r < options.size() else 0
	zone.visible = true
	var r: int = await choisir(options, zone, colonnes, larg_col, hauteur, annulable, Vector2(12, 8), actifs)
	zone.visible = false
	return r

func _secouer(cote: String) -> void:
	if auto or not is_inside_tree():
		return
	var s: ColorRect = _sprite[cote]
	var x := s.position.x
	var t := create_tween()
	for i in 3:
		t.tween_property(s, "position:x", x + 6, 0.04)
		t.tween_property(s, "position:x", x - 6, 0.04)
	t.tween_property(s, "position:x", x, 0.04)
	await t.finished

# rejoue les evenements produits par le moteur
func _jouer(evs: Array) -> void:
	var k := 0
	while k < evs.size():
		var e: Dictionary = evs[k]
		match String(e["t"]):
			"msg":
				var suite_auto: bool = k + 1 < evs.size() and String(evs[k + 1]["t"]) == "pause"
				await _msg(String(e["texte"]), not suite_auto)
			"maj":
				var cote := String(e["cote"])
				var d := _appliquer(cote, e["etat"], bool(e["anime"]))
				# degats : la barre de PV descend PENDANT que le sprite est secoue (le "secousse" qui suit est joue en meme temps)
				var secoue: bool = k + 1 < evs.size() and String(evs[k + 1]["t"]) == "secousse" and String(evs[k + 1]["cote"]) == cote
				if secoue:
					k += 1
					_secouer(cote)   # volontairement sans await : on n'attend pas la fin, la barre s'anime deja
				if d > 0.0 or secoue:
					await _pause(maxf(d + 0.15, 0.3 if secoue else 0.0))
				# K.O. : le sprite ne disparait qu'une fois la barre arrivee a 0
				if int(e["etat"]["pv"]) <= 0 and bool(e["anime"]):
					_sprite[cote].visible = false
			"envoi":
				_appliquer(String(e["cote"]), e["etat"], false)
				if jeu != null and String(e["cote"]) == "e":
					jeu.enregistrer_vu(String(e["etat"]["espece"]))
				if bool(e["etat"]["shiny"]) and String(e["cote"]) == "e":
					await _msg("Un POKEMON chromatique !")
				await _pause(0.2)
			"secousse":
				await _secouer(String(e["cote"]))
			"ko":
				_sprite[String(e["cote"])].visible = false
				await _pause(0.3)
			"pause":
				await _pause(float(e["s"]))
			"balle":
				await _anim_balle(e)
		k += 1

# ---------- deroulement ----------

func _debut() -> void:
	en_cours = true
	visible = true
	actif = not auto
	# rien n'est affiche tant que l'evenement "envoi" n'a pas rempli bandeaux et sprites (sinon : infos du combat precedent)
	for c in ["j", "e"]:
		_sprite[c].visible = false
		_panneaux[c].visible = false
		_info[c].erase("niv_val")

var _balle_noeud: ColorRect

# lancer de balle : trajet, secousses, puis la balle se fige (capture) ou le Pokemon ressort (rate)
func _anim_balle(e: Dictionary) -> void:
	if auto or not is_inside_tree():
		return
	_balle_noeud = ColorRect.new()
	_balle_noeud.color = Color(0.85, 0.15, 0.15)
	_balle_noeud.size = Vector2(14, 14)
	_balle_noeud.position = _sprite["j"].position + Vector2(70, 20)
	add_child(_balle_noeud)
	var cible: Vector2 = _sprite["e"].position + Vector2(28, 28)
	var t := create_tween()
	t.tween_property(_balle_noeud, "position", cible, 0.5)
	await t.finished
	_sprite["e"].visible = false
	for k in int(e["secousses"]):
		await _pause(0.5)
		var t2 := create_tween()
		t2.tween_property(_balle_noeud, "position:x", cible.x + 6, 0.1)
		t2.tween_property(_balle_noeud, "position:x", cible.x - 6, 0.2)
		t2.tween_property(_balle_noeud, "position:x", cible.x, 0.1)
		await t2.finished
	await _pause(0.5)
	if bool(e["capture"]):
		_balle_noeud.color = Color(0.4, 0.4, 0.4)
	else:
		_balle_noeud.queue_free()
		_balle_noeud = null

func _fin() -> void:
	if _balle_noeud != null:
		_balle_noeud.queue_free()
		_balle_noeud = null
	visible = false
	actif = false
	en_cours = false

func _lancer(eq: Array, en: Array, sauvage: bool, dresseur: String) -> String:
	equipe = eq
	ennemis = en
	bat = Bataille.new()
	bat.rng = rng
	_debut()
	bat.demarrer(eq, en, sauvage, dresseur)
	await _jouer(bat.vider_evenements())
	while bat.fin == "":
		var act: Dictionary = await _choisir_action()
		if act.is_empty():
			continue
		bat.tour(act)
		await _jouer(bat.vider_evenements())
		if bat.fin == "" and bat.remplacement_requis():
			var idx: int = await _choisir_pokemon(false)
			bat.remplacer(idx)
			await _jouer(bat.vider_evenements())
	await _apres_combat()
	if bat.fin == "capture":
		await _apres_capture(bat.capture)
	var res: String = bat.fin
	_fin()
	return res

# renvoie vrai si le joueur gagne un combat de dresseur
func combattre(eq: Array, en: Array, nom_dresseur := "Dresseur") -> bool:
	return await _lancer(eq, en, false, nom_dresseur) == "victoire"

# Pokemon sauvage : renvoie "victoire", "defaite", "fuite" ou "capture"
func combat_sauvage(eq: Array, sauvage_p) -> String:
	return await _lancer(eq, [sauvage_p], true, "")

# apprentissage des attaques en attente puis evolutions
func _apres_combat() -> void:
	for p in equipe:
		while not p.attaques_en_attente.is_empty():
			var id: String = p.attaques_en_attente.pop_front()
			await _apprendre(p, id)
	if bat.fin == "defaite":
		return
	for p in bat.a_evoluer:
		var vers: String = p.evolution_possible({})
		if vers == "":
			continue
		var avant: String = p.nom
		await _msg("Quoi ? %s evolue !" % avant.to_upper())
		p.evoluer(vers)
		if jeu != null:
			jeu.enregistrer_capture(vers)
		await _msg("%s a evolue en %s !" % [avant.to_upper(), p.nom_espece().to_upper()])
		for e in Donnees.espece(vers).get("attaques_niveau", []):
			if int(e[0]) == p.niveau and not p.connait(String(e[1])):
				if p.attaques.size() < int(Donnees.regle("attaques_max", 4)):
					p._ajouter_attaque(String(e[1]))
					await _msg("%s apprend %s !" % [p.nom.to_upper(), Donnees.attaque(String(e[1])).get("nom", e[1])])
				else:
					await _apprendre(p, String(e[1]))

# le Pokemon capture rejoint l'equipe, ou une boite du PC si l'equipe est pleine
func _apres_capture(p) -> void:
	if jeu == null:
		return
	p.dresseur_origine = String(jeu.nom_joueur)
	var ou: Dictionary = jeu.recevoir_pokemon(p)
	if ou.get("ou", "") == "equipe":
		await _msg("%s a ete ajoute a l'equipe." % p.nom.to_upper())
	else:
		await _msg("%s a ete envoye dans la BOITE %d du PC." % [p.nom.to_upper(), int(ou.get("boite", 0)) + 1])

func _apprendre(p, id: String) -> void:
	var nom_a := String(Donnees.attaque(id).get("nom", id))
	if p.attaques.size() < int(Donnees.regle("attaques_max", 4)):
		p._ajouter_attaque(id)
		await _msg("%s apprend %s !" % [p.nom.to_upper(), nom_a.to_upper()])
		return
	await _msg("%s veut apprendre %s, mais il connait deja %d attaques." % [p.nom.to_upper(), nom_a.to_upper(), p.attaques.size()])
	var noms: Array = p.attaques.map(func(a): return String(Donnees.attaque(a["id"]).get("nom", a["id"])))
	noms.append("NE PAS APPRENDRE")
	_texte.text = "Quelle attaque oublier pour apprendre %s ?" % nom_a.to_upper()
	var k: int = await _menu(noms, _attaques_zone, 2, 220, false)
	if k < 0 or k >= p.attaques.size():
		await _msg("%s n'apprend pas %s." % [p.nom.to_upper(), nom_a.to_upper()])
		return
	var oubliee := String(Donnees.attaque(p.attaques[k]["id"]).get("nom", p.attaques[k]["id"]))
	var pp: int = int(Donnees.attaque(id).get("pp", 10))
	p.attaques[k] = {"id": id, "pp": pp, "pp_max": pp}
	await _msg("1, 2 et... PAF ! %s oublie %s et apprend %s !" % [p.nom.to_upper(), oubliee.to_upper(), nom_a.to_upper()])

# Demonstration de capture (le joueur regarde, rien n'est ajoute a l'equipe ni au Pokedex) :
# un Pokemon sauvage apparait, "dresseur" l'affaiblit puis lui lance une POKe BALL.
func demo_capture(espece: String, niveau: int, dresseur: String, couleur := "#8a6a4a") -> void:
	var sauvage = Pokemon.creer(espece, niveau)
	bat = null
	ennemis = [sauvage]
	equipe = []
	actif_e = sauvage
	actif_j = null
	en_cours = true
	visible = true
	actif = not auto
	_maj_p("e", sauvage, false)
	_panneaux["j"].visible = false
	_sprite["j"].color = Color(couleur)
	_sprite["j"].visible = true
	var nom_e: String = sauvage.nom.to_upper()
	await _msg("Un %s sauvage apparait !" % nom_e)
	await _msg("%s : D'abord, il faut affaiblir le POKEMON sauvage." % dresseur.to_upper())
	sauvage.pv = maxi(1, int(sauvage.stats["pv"] / 5))
	_maj_p("e", sauvage)
	await _pause(0.6)
	await _msg("Le %s est affaibli ! Ses PV sont tres bas." % nom_e)
	await _msg("%s : Maintenant, on lance une POKe BALL !" % dresseur.to_upper())
	await _msg("%s lance une POKe BALL !" % dresseur.to_upper(), false)
	var balle := ColorRect.new()
	balle.color = Color(0.85, 0.15, 0.15)
	balle.size = Vector2(12, 12)
	balle.position = _sprite["j"].position + Vector2(70, 20)
	add_child(balle)
	var cible: Vector2 = _sprite["e"].position + Vector2(30, 30)
	if not auto:
		var t := create_tween()
		t.tween_property(balle, "position", cible, 0.6)
		await t.finished
	else:
		balle.position = cible
	_sprite["e"].visible = false
	for k in 3:
		await _pause(0.5)
		if not auto:
			var t2 := create_tween()
			t2.tween_property(balle, "position:x", cible.x + 6, 0.1)
			t2.tween_property(balle, "position:x", cible.x - 6, 0.2)
			t2.tween_property(balle, "position:x", cible.x, 0.1)
	await _pause(0.5)
	balle.color = Color(0.4, 0.4, 0.4)
	await _msg("Ca y est ! %s est capture !" % nom_e)
	balle.queue_free()
	_panneaux["j"].visible = true
	_sprite["e"].visible = true
	visible = false
	actif = false
	en_cours = false
	ennemis = []

# ---------- choix du joueur ----------

# renvoie l'action choisie ({} si le joueur a annule / revient au menu)
func _choisir_action() -> Dictionary:
	while true:
		_texte.size.x = 216
		_texte.text = "Que doit faire %s ?" % actif_j.nom.to_upper()
		var m := await _menu(["COMBAT", "SAC", "POKEMON", "FUITE"], _menu_zone, 2, 108)
		match m:
			1:
				var o: Dictionary = await _choisir_objet()
				if not o.is_empty():
					return o
			2:
				var idx: int = await _choisir_pokemon(true)
				if idx >= 0:
					return {"t": "changer", "index": idx}
			3:
				if not bat.peut_fuir():
					await _msg("On ne s'enfuit pas d'un combat de dresseur !")
				else:
					return {"t": "fuite"}
			_:
				var id := await _choisir_attaque()
				if id != "":
					return {"t": "attaque", "id": id}
	return {}

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

# liste de l'equipe ; renvoie l'index choisi ou -1. annulable = false : remplacement obligatoire apres un K.O.
func _choisir_pokemon(annulable: bool) -> int:
	while true:
		var noms: Array = []
		var actifs: Array = []
		for p in equipe:
			var st = COULEURS_STATUT.get(p.statut)
			noms.append("%s Nv%d  PV %d/%d %s" % [p.nom.to_upper(), p.niveau, maxi(0, p.pv), p.stats["pv"], st[0] if st != null else ""])
			actifs.append(not p.ko() and p != actif_j)
		if not annulable:
			_texte.text = "Quel POKEMON envoyer ?"
		var k: int = await _menu(noms, _liste_zone, 1, 440, annulable, actifs, 30)
		if k >= 0 and actifs[k]:
			return k
		if annulable:
			return -1
		for i in equipe.size():     # choix invalide (tests) : premier Pokemon valide
			if actifs[i]:
				return i
	return -1

# objets de soin utilisables en combat (data/objets.json : soin_pv, soin_statut) ; renvoie une action ou {}
func _choisir_objet() -> Dictionary:
	if jeu == null:
		await _msg("Le sac est vide pour l'instant.")
		return {}
	var ids: Array = []
	var noms: Array = []
	for id in jeu.sac:
		var o: Dictionary = Donnees.objet(String(id))
		if o.has("soin_pv") or o.has("soin_statut") or o.has("balle"):
			ids.append(String(id))
			noms.append("%s  x%d" % [Donnees.nom_objet(String(id)), int(jeu.sac[id])])
	if ids.is_empty():
		await _msg("Tu n'as aucun objet utilisable en combat.")
		return {}
	var k: int = await _menu(noms, _liste_zone, 1, 440, true, [], 30)
	if k < 0:
		return {}
	var o: Dictionary = Donnees.objet(ids[k])
	if o.has("balle"):
		if not bat.sauvage:
			await _msg("Tu ne peux pas voler le POKEMON d'un dresseur !")
			return {}
		if equipe.size() >= int(Donnees.regle("taille_equipe", 6)) and jeu.place_libre_boite().x < 0:
			await _msg("Les boites du PC sont pleines !")
			return {}
		jeu.retirer_objet(ids[k], 1)
		return {"t": "balle", "id": ids[k]}
	var cible: int = await _choisir_pokemon(true)
	if cible < 0:
		return {}
	var p = equipe[cible]
	var utile: bool = (o.has("soin_pv") and not p.ko() and p.pv < p.stats["pv"]) or (o.has("soin_statut") and p.statut != "")
	if not utile:
		await _msg("Ca n'aurait aucun effet.")
		return {}
	jeu.retirer_objet(ids[k], 1)
	return {"t": "objet", "id": ids[k], "index": cible}
