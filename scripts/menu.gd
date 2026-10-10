extends "res://scripts/ecran.gd"
# Menu en jeu (touche Tab / M / Echap) : POKéDEX, POKéMON, SAC, fiche du joueur, SAUVEGARDER, QUITTER.

signal quitter_demande

const Donnees := preload("res://scripts/donnees.gd")
const Sauvegarde := preload("res://scripts/sauvegarde.gd")

var _jeu
var _racine: Control

func installer(jeu) -> void:
	_jeu = jeu
	layer = 25
	visible = false
	_racine = Control.new()
	_racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_racine)

func _options() -> Array:
	var o: Array = []     # [identifiant, texte]
	if _jeu.a_drapeau("pokedex_obtenu"):
		o.append(["pokedex", "POKéDEX"])
	if not _jeu.equipe.is_empty():
		o.append(["pokemon", "POKéMON"])
	o.append(["sac", "SAC"])
	o.append(["joueur", String(_jeu.nom_joueur).to_upper()])
	o.append(["sauvegarde", "SAUVEGARDER"])
	o.append(["quitter", "QUITTER"])
	return o

func ouvrir() -> void:
	visible = true
	actif = true
	var dernier := 0
	while true:
		var opts := _options()
		var textes: Array = opts.map(func(x): return x[1])
		var zone := panneau(Rect2(300, 8, 172, opts.size() * 26 + 16), _racine)
		var r: int = await choisir(textes, zone, 1, 160, 26, true, Vector2(12, 8), [], dernier)
		zone.queue_free()
		if r < 0:
			break
		dernier = r
		match String(opts[r][0]):
			"pokedex": await _pokedex()
			"pokemon": await _pokemon()
			"sac": await _sac()
			"joueur": await _fiche_joueur()
			"sauvegarde": await _sauvegarder()
			"quitter":
				if await oui_non("Quitter le jeu ?\nLa partie non sauvegardee sera perdue.", _racine):
					quitter_demande.emit()
					break
	vider(_racine)
	actif = false
	visible = false

func _plein_ecran() -> Panel:
	return panneau(Rect2(0, 0, 480, 320), _racine)

func _barre(parent: Node, pos: Vector2, largeur: float, part: float) -> void:
	var fond := ColorRect.new()
	fond.color = Color(0.25, 0.25, 0.25)
	fond.position = pos
	fond.size = Vector2(largeur + 4, 10)
	parent.add_child(fond)
	var r := ColorRect.new()
	r.position = Vector2(2, 2)
	r.size = Vector2(largeur * clampf(part, 0.0, 1.0), 6)
	r.color = Color(0.2, 0.75, 0.3) if part > 0.5 else (Color(0.95, 0.8, 0.1) if part > 0.2 else Color(0.85, 0.2, 0.15))
	fond.add_child(r)

func _couleur(espece_id: String) -> Color:
	return Color(String(Donnees.espece(espece_id).get("couleur", "#888888")))

# ---------- POKéMON ----------

func _pokemon() -> void:
	var ecran := _plein_ecran()
	var liste := Control.new()
	ecran.add_child(liste)
	var deco := Control.new()
	ecran.add_child(deco)
	var i := 0
	while true:
		vider(deco)
		var textes: Array = []
		for k in _jeu.equipe.size():
			var p = _jeu.equipe[k]
			textes.append("%s   Nv%d\n      PV %d/%d" % [p.nom.to_upper(), p.niveau, p.pv, p.stats["pv"]])
			var c := ColorRect.new()
			c.color = _couleur(p.espece_id)
			c.position = Vector2(400, 12 + k * 48)
			c.size = Vector2(28, 28)
			deco.add_child(c)
			_barre(deco, Vector2(220, 30 + k * 48), 120.0, float(p.pv) / float(p.stats["pv"]))
		var r: int = await choisir(textes, liste, 1, 200, 48, true, Vector2(12, 8), [], i)
		if r < 0:
			break
		i = r
		await _resume_pokemon(_jeu.equipe[r])
	ecran.queue_free()

func _resume_pokemon(p) -> void:
	var ecran := _plein_ecran()
	etiquette(ecran, Vector2(16, 8), 22, "%s   Nv%d" % [p.nom.to_upper(), p.niveau])
	var c := ColorRect.new()
	c.color = _couleur(p.espece_id)
	c.position = Vector2(24, 50)
	c.size = Vector2(96, 96)
	ecran.add_child(c)
	var types: Array = p.types.map(func(t): return String(t).to_upper())
	etiquette(ecran, Vector2(16, 154), 13, "TYPE  " + " / ".join(types))
	etiquette(ecran, Vector2(16, 176), 12, "N° %03d" % int(Donnees.espece(p.espece_id).get("numero", 0)))
	var st: Dictionary = p.stats
	var lignes := ["PV         %d / %d" % [p.pv, st["pv"]], "ATTAQUE    %d" % st["atk"], "DEFENSE    %d" % st["def"],
		"VITESSE    %d" % st["vit"], "SPECIAL    %d" % st["spe"]]
	for k in lignes.size():
		etiquette(ecran, Vector2(170, 64 + k * 22), 15, lignes[k])
	_barre(ecran, Vector2(170, 50), 150.0, float(p.pv) / float(st["pv"]))
	var prochain: int = p.exp_pour_niveau(p.niveau + 1) if p.niveau < 100 else p.exp
	etiquette(ecran, Vector2(170, 180), 13, "POINTS EXP   %d" % p.exp)
	etiquette(ecran, Vector2(170, 196), 13, "NIVEAU SUIVANT  dans %d" % maxi(0, prochain - p.exp))
	var att := panneau(Rect2(8, 214, 464, 98), ecran)
	for k in p.attaques.size():
		var a: Dictionary = p.attaques[k]
		var nom := String(Donnees.attaque(a["id"]).get("nom", a["id"])).to_upper()
		etiquette(att, Vector2(14 + (k % 2) * 228, 8 + (k / 2) * 40), 14, "%s\n   PP %d/%d" % [nom, a["pp"], a["pp_max"]])
	while true:
		var n: String = await touche
		if n == "annuler" or n == "action" or n == "menu":
			break
	ecran.queue_free()

# ---------- SAC ----------

func _nom_objet(id: String) -> String:
	return id.replace("_", " ").to_upper()

func _sac() -> void:
	var ecran := _plein_ecran()
	etiquette(ecran, Vector2(16, 6), 18, "SAC")
	etiquette(ecran, Vector2(330, 8), 14, "ARGENT  %d P" % _jeu.argent)
	var liste := Control.new()
	ecran.add_child(liste)
	var ids: Array = _jeu.sac.keys()
	if ids.is_empty():
		etiquette(ecran, Vector2(30, 60), 16, "Le sac est vide.")
		while true:
			var n: String = await touche
			if n == "annuler" or n == "action" or n == "menu":
				break
		ecran.queue_free()
		return
	var textes: Array = ids.map(func(id): return "%s   x%d" % [_nom_objet(id), _jeu.sac[id]])
	textes.append("FERMER")
	while true:
		var r: int = await choisir(textes, liste, 1, 300, 28, true, Vector2(24, 40), [], 0, 8)
		if r < 0 or r == ids.size():
			break
		await message("%s ne peut pas encore etre utilise ici." % _nom_objet(ids[r]), ecran)
	ecran.queue_free()

# ---------- POKéDEX ----------

func _pokedex() -> void:
	var ecran := _plein_ecran()
	etiquette(ecran, Vector2(16, 6), 18, "POKéDEX")
	etiquette(ecran, Vector2(250, 8), 13, "VUS %d    CAPTURES %d" % [_jeu.vus.size(), _jeu.captures.size()])
	var liste := Control.new()
	ecran.add_child(liste)
	var fiche := panneau(Rect2(290, 36, 182, 170), ecran)
	var ids: Array = Donnees.toutes_les_especes()
	var textes: Array = []
	for id in ids:
		var e: Dictionary = Donnees.espece(id)
		var num := "%03d" % int(e.get("numero", 0))
		if _jeu.vus.has(id) or _jeu.captures.has(id):
			textes.append("%s %s%s" % [num, String(e.get("nom", id)).to_upper(), "  O" if _jeu.captures.has(id) else ""])
		else:
			textes.append("%s ----------" % num)
	var i := 0
	while true:
		var r: int = await choisir_suivi(textes, liste, fiche, ids, i)
		if r < 0:
			break
		i = r
	ecran.queue_free()

# comme choisir() mais met la fiche a jour quand le curseur bouge
func choisir_suivi(textes: Array, liste: Control, fiche: Panel, ids: Array, depart: int) -> int:
	vider(liste)
	var visibles := mini(9, textes.size())
	var labels: Array = []
	for k in visibles:
		labels.append(etiquette(liste, Vector2(16, 36 + k * 24)))
	enregistrer_zones(liste, visibles, 1, 250, 24, Vector2(16, 36))
	var i := depart
	var debut := 0
	var res := -2
	while res == -2:
		if i < debut: debut = i
		if i >= debut + visibles: debut = i - visibles + 1
		for k in labels.size():
			labels[k].text = ("> " if debut + k == i else "  ") + String(textes[debut + k])
		_maj_fiche_dex(fiche, ids[i])
		var n: String = await touche
		if n.begins_with("survol:") or n.begins_with("clic:"):
			i = mini(debut + int(n.substr(n.find(":") + 1)), textes.size() - 1)
			continue
		match n:
			"haut": i = maxi(0, i - 1)
			"bas": i = mini(textes.size() - 1, i + 1)
			"annuler", "menu": res = -1
			"action": res = i
	effacer_zones()
	return res

func _maj_fiche_dex(fiche: Panel, id: String) -> void:
	vider(fiche)
	var e: Dictionary = Donnees.espece(id)
	if not (_jeu.vus.has(id) or _jeu.captures.has(id)):
		etiquette(fiche, Vector2(14, 12), 14, "N° %03d\n\nPOKéMON inconnu" % int(e.get("numero", 0)))
		return
	var c := ColorRect.new()
	c.color = _couleur(id)
	c.position = Vector2(14, 12)
	c.size = Vector2(64, 64)
	fiche.add_child(c)
	var types: Array = e.get("types", []).map(func(t): return String(t).to_upper())
	etiquette(fiche, Vector2(14, 86), 14, String(e.get("nom", id)).to_upper())
	etiquette(fiche, Vector2(14, 108), 12, " / ".join(types))
	etiquette(fiche, Vector2(14, 132), 12, "Capturé" if _jeu.captures.has(id) else "Vu seulement")

# ---------- fiche du joueur ----------

func _fiche_joueur() -> void:
	var ecran := _plein_ecran()
	etiquette(ecran, Vector2(16, 8), 22, String(_jeu.nom_joueur).to_upper())
	var lignes := ["ARGENT      %d P" % _jeu.argent, "POKéDEX     %d vus / %d capturés" % [_jeu.vus.size(), _jeu.captures.size()],
		"TEMPS       %s" % Sauvegarde.temps_texte(_jeu.temps_jeu), "POKéMON     %d dans l'équipe" % _jeu.equipe.size()]
	for k in lignes.size():
		etiquette(ecran, Vector2(24, 52 + k * 28), 16, lignes[k])
	etiquette(ecran, Vector2(24, 176), 14, "BADGES")
	for k in _jeu.BADGES.size():
		var b: Dictionary = _jeu.BADGES[k]
		var x: int = 24 + (k % 4) * 112
		var y: int = 200 + (k / 4) * 54
		var c := ColorRect.new()
		var obtenu: bool = _jeu.badges.has(b["id"])
		c.color = Color(String(b["couleur"])) if obtenu else Color(0.75, 0.75, 0.75)
		c.position = Vector2(x, y)
		c.size = Vector2(28, 28)
		ecran.add_child(c)
		etiquette(ecran, Vector2(x + 34, y + 4), 12, String(b["nom"]) if obtenu else "---")
	while true:
		var n: String = await touche
		if n == "annuler" or n == "action" or n == "menu":
			break
	ecran.queue_free()

# ---------- sauvegarde ----------

func _sauvegarder() -> void:
	var slot: int = _jeu.slot_actuel
	if slot < 1:
		await message("Aucun emplacement de sauvegarde n'est associé à cette partie.", _racine)
		return
	var ancien := Sauvegarde.resume(slot)
	if not await oui_non("Sauvegarder la partie dans l'emplacement %d ?\n(%s)" % [slot, ancien], _racine):
		return
	if Sauvegarde.ecrire(slot, _jeu.exporter()):
		await message("%s a sauvegardé la partie !" % String(_jeu.nom_joueur).to_upper(), _racine)
	else:
		await message("Échec de la sauvegarde...", _racine)
