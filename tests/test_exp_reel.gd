extends SceneTree
# combat en mode reel (touches, animations) : la barre d'EXP finit a jour, y compris apres une montee de niveau
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
	for cas in [0, 1]:
		var fort = Pokemon.creer("salameche", 12)
		if cas == 1:
			fort.exp = fort.exp_seuil(13) - 2   # monte de niveau avec le gain
		var faible = Pokemon.creer("rattata", 3)
		var niv0: int = fort.niveau
		var fini := [false]
		var lancer := func():
			await cb.combat_sauvage([fort], faible)
			fini[0] = true
		lancer.call()
		var n := 0
		while not fini[0] and n < 200:
			await create_timer(0.25).timeout
			if cb.en_cours and not fini[0]:
				cb.appuyer("action")
			n += 1
		ok(fini[0], "cas %d : combat termine" % cas)
		var nv: int = fort.niveau
		var larg: float = cb._info["j"]["exp"].size.x
		var mn: int = fort.exp_seuil(nv)
		var att: float = clampf(float(fort.exp - mn) / float(fort.exp_seuil(nv + 1) - mn), 0.0, 1.0) * 206.0
		ok(absf(larg - att) < 0.6, "cas %d : barre %.1f attendu %.1f (niv %d -> %d)" % [cas, larg, att, niv0, nv])
		if cas == 1: ok(nv == niv0 + 1, "cas 1 : montee de niveau")
	quit(1 if erreurs > 0 else 0)
