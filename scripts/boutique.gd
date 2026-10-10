extends "res://scripts/ecran.gd"
# Boutique (Poke Mart) : ACHETER / VENDRE / SORTIR.
# Utilisation : await boutique.ouvrir(["poke_ball", "potion"])   (ou l'action d'evenement "boutique")
# Les prix viennent de data/objets.json ("prix") ; on rachete a la moitie du prix ; les objets "cle" ne se vendent pas.
# Clavier : fleches / Entree / X.  Souris : survol, clic, clic droit pour annuler, molette (ou fleches) pour la quantite.

const Donnees := preload("res://scripts/donnees.gd")

var _jeu
var _racine: Control
var _argent: Label
var _bulle: Label

func installer(jeu) -> void:
	_jeu = jeu
	layer = 25
	visible = false
	_racine = Control.new()
	_racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_racine)

func _maj_argent() -> void:
	_argent.text = "%d P" % _jeu.argent

func ouvrir(stock: Array) -> void:
	visible = true
	actif = true
	var fond := panneau(Rect2(0, 0, 480, 320), _racine)
	fond.modulate = Color(0.9, 0.93, 0.85)
	var pa := panneau(Rect2(330, 8, 142, 34), _racine)
	etiquette(pa, Vector2(10, 4), 12, "ARGENT")
	_argent = etiquette(pa, Vector2(70, 4), 14)
	_maj_argent()
	var pb := panneau(Rect2(8, 236, 464, 76), _racine)
	_bulle = etiquette(pb, Vector2(12, 10), 15)
	_bulle.size = Vector2(440, 56)
	_bulle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var dernier := 0
	while true:
		_bulle.text = "Bienvenue ! Que puis-je faire pour vous ?"
		var zone := panneau(Rect2(8, 8, 150, 104), _racine)
		var r: int = await choisir(["ACHETER", "VENDRE", "SORTIR"], zone, 1, 140, 28, true, Vector2(12, 10), [], dernier)
		zone.queue_free()
		if r < 0 or r == 2:
			break
		dernier = r
		if r == 0:
			await _acheter(stock)
		else:
			await _vendre()
	await message("Merci ! A bientot !", _racine)
	vider(_racine)
	actif = false
	visible = false

func _ligne(id: String, prix: int) -> String:
	return "%s   %d P" % [Donnees.nom_objet(id), prix]

func _acheter(stock: Array) -> void:
	var liste := panneau(Rect2(8, 8, 316, 224), _racine)
	var textes: Array = stock.map(func(id): return _ligne(id, int(Donnees.objet(id).get("prix", 0))))
	textes.append("RETOUR")
	var dernier := 0
	while true:
		_bulle.text = "Que voulez-vous acheter ?"
		var r: int = await choisir(textes, liste, 1, 300, 28, true, Vector2(14, 10), [], dernier, 7)
		if r < 0 or r == stock.size():
			break
		dernier = r
		var id := String(stock[r])
		var prix := int(Donnees.objet(id).get("prix", 0))
		if prix <= 0 or _jeu.argent < prix:
			await message("Tu n'as pas assez d'argent.", _racine)
			continue
		var n: int = await _quantite(prix, mini(99, _jeu.argent / prix))
		if n <= 0:
			continue
		if await oui_non("%s x%d, ca fait %d P. D'accord ?" % [Donnees.nom_objet(id), n, n * prix], _racine):
			_jeu.argent -= n * prix
			_jeu.donner_objet(id, n)
			_maj_argent()
			await message("Voila ! Merci beaucoup !", _racine)
			# bonus eventuel (data/objets.json, cle "bonus") : ex. 1 HONOR BALL par tranche de 10 POKe BALLS
			var bonus: Dictionary = Donnees.objet(id).get("bonus", {})
			var k := (n / maxi(1, int(bonus.get("par", 1)))) * int(bonus.get("quantite", 1)) if not bonus.is_empty() else 0
			if k > 0:
				_jeu.donner_objet(String(bonus["objet"]), k)
				await message("En bonus, voici %d %s !" % [k, Donnees.nom_objet(String(bonus["objet"]))], _racine)
	liste.queue_free()

func _vendre() -> void:
	var ids: Array = []
	for id in _jeu.sac:
		var o: Dictionary = Donnees.objet(String(id))
		if o.has("prix") and not bool(o.get("cle", false)):
			ids.append(id)
	if ids.is_empty():
		await message("Tu n'as rien a me vendre.", _racine)
		return
	var liste := panneau(Rect2(8, 8, 316, 224), _racine)
	var dernier := 0
	while true:
		ids = ids.filter(func(id): return int(_jeu.sac.get(id, 0)) > 0)
		if ids.is_empty():
			break
		var textes: Array = ids.map(func(id): return "%s x%d   %d P" % [Donnees.nom_objet(id), _jeu.sac[id], int(Donnees.objet(id)["prix"]) / 2])
		textes.append("RETOUR")
		_bulle.text = "Que voulez-vous vendre ?"
		var r: int = await choisir(textes, liste, 1, 300, 28, true, Vector2(14, 10), [], mini(dernier, textes.size() - 1), 7)
		if r < 0 or r == ids.size():
			break
		dernier = r
		var id := String(ids[r])
		var prix := int(Donnees.objet(id)["prix"]) / 2
		var n: int = await _quantite(prix, int(_jeu.sac[id]))
		if n <= 0:
			continue
		if await oui_non("%s x%d : je vous en donne %d P. D'accord ?" % [Donnees.nom_objet(id), n, n * prix], _racine):
			_jeu.retirer_objet(id, n)
			_jeu.argent += n * prix
			_maj_argent()
			await message("Merci !", _racine)
	liste.queue_free()

# choix d'une quantite (1 a maxi) ; renvoie 0 si annule
func _quantite(prix_unitaire: int, maxi_q: int) -> int:
	var p := panneau(Rect2(284, 120, 188, 82), _racine)
	var l := etiquette(p, Vector2(12, 8), 16)
	var aide := etiquette(p, Vector2(12, 40), 10, "haut / bas ou molette : quantite\nEntree ou clic : valider")
	aide.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
	var n := 1
	var res := -1
	while res < 0:
		l.text = "x%02d     %d P" % [n, n * prix_unitaire]
		var t: String = await touche
		match t:
			"haut": n = mini(n + 1, maxi_q)
			"bas": n = maxi(n - 1, 1)
			"droite": n = mini(n + 10, maxi_q)
			"gauche": n = maxi(n - 10, 1)
			"action": res = n
			"annuler", "menu": res = 0
	p.queue_free()
	return res
