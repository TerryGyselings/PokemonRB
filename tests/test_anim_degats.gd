extends SceneTree
# degats : barre de PV et secousse simultanees ; K.O. : la barre arrive a 0 AVANT que le sprite disparaisse
var erreurs := 0
func ok(c: bool, msg: String) -> void:
	print(("OK   " if c else "FAIL ") + msg)
	if not c: erreurs += 1
func _init() -> void:
	load("res://scripts/pokemon.gd").deterministe = true
	var Combat := load("res://scripts/combat.gd")
	var Pokemon := load("res://scripts/pokemon.gd")
	var cb = Combat.new()
	root.add_child(cb)
	await process_frame
	var p = Pokemon.creer("rattata", 20)
	cb._debut()
	cb._appliquer("e", cb._snap(p), false)
	var x0: float = cb._sprite["e"].position.x
	var larg0: float = cb._info["e"]["rempli"].size.x
	# 1) coup non fatal : on echantillonne en cours d'animation
	var etat1: Dictionary = cb._snap(p)
	etat1["pv"] = int(p.stats["pv"] / 2)
	var evs1: Array = [{"t": "maj", "cote": "e", "etat": etat1, "anime": true}, {"t": "secousse", "cote": "e"}]
	cb._jouer(evs1)
	var dx := 0.0
	var larg_mid := larg0
	var simultane := false
	for q in 12:
		await create_timer(0.03).timeout
		var d: float = absf(cb._sprite["e"].position.x - x0)
		var l: float = cb._info["e"]["rempli"].size.x
		dx = maxf(dx, d)
		larg_mid = l
		if d > 0.5 and l < larg0 - 0.5: simultane = true
	ok(larg_mid < larg0, "la barre de PV descend (%.1f / %.1f)" % [larg_mid, larg0])
	ok(dx > 0.5, "le sprite est secoue (decalage max %.1f)" % dx)
	ok(simultane, "les deux au meme moment")
	await create_timer(0.8).timeout
	# 2) coup fatal
	var etat2: Dictionary = cb._snap(p)
	etat2["pv"] = 0
	var evs2: Array = [{"t": "maj", "cote": "e", "etat": etat2, "anime": true}, {"t": "secousse", "cote": "e"}]
	cb._jouer(evs2)
	await create_timer(0.25).timeout
	ok(cb._sprite["e"].visible, "K.O. : le sprite est encore la pendant que la barre descend")
	ok(cb._info["e"]["rempli"].size.x > 0.5, "K.O. : la barre n'est pas encore a 0 (%.1f)" % cb._info["e"]["rempli"].size.x)
	await create_timer(1.0).timeout
	ok(cb._info["e"]["rempli"].size.x < 0.6, "K.O. : la barre est a 0")
	ok(not cb._sprite["e"].visible, "K.O. : le sprite a disparu apres la barre")
	quit(1 if erreurs > 0 else 0)
