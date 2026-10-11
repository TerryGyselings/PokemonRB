extends SceneTree
# barre d'EXP et bandeaux de depart du combat
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
	cb.auto = true
	cb.rng.seed = 3
	var fort = Pokemon.creer("salameche", 12)
	var faible = Pokemon.creer("rattata", 3)
	var avant: int = fort.exp
	var r: String = await cb.combat_sauvage([fort], faible)
	ok(r == "victoire" and fort.exp > avant, "victoire (%s) exp %d -> %d" % [r, avant, fort.exp])
	var larg: float = cb._info["j"]["exp"].size.x
	var att: float = clampf(float(fort.exp - fort.exp_seuil(fort.niveau)) / float(fort.exp_seuil(fort.niveau + 1) - fort.exp_seuil(fort.niveau)), 0.0, 1.0) * 206.0
	ok(absf(larg - att) < 0.6, "barre d'EXP a jour (%.1f attendu %.1f)" % [larg, att])
	# 2e combat : au moment de l'envoi les bandeaux ne montrent plus l'ancien combat
	var autre = Pokemon.creer("pikachu", 7)
	var sauv = Pokemon.creer("roucool", 4)
	cb.auto = false
	cb.combat_sauvage([autre], sauv)
	await process_frame
	ok(not cb._panneaux["j"].visible and not cb._panneaux["e"].visible, "bandeaux caches au debut du combat")
	ok(not cb._sprite["j"].visible and not cb._sprite["e"].visible, "sprites caches au debut du combat")
	quit(1 if erreurs > 0 else 0)
