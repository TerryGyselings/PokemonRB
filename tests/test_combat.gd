extends SceneTree
# Combat : formules, ordre des tours, effets, K.O., EXP (mode "auto", sans interface)
var erreurs := 0
func ok(c: bool, msg: String) -> void:
	print(("OK   " if c else "FAIL ") + msg)
	if not c: erreurs += 1
func _init() -> void:
	var Pokemon := load("res://scripts/pokemon.gd")
	var Combat := load("res://scripts/combat.gd")
	var cb = Combat.new()
	root.add_child(cb)
	await process_frame
	cb.auto = true
	cb.rng.seed = 42
	# degats : Salameche Nv5 (Flammeche) contre Bulbizarre Nv5, super efficace + STAB
	var sal = Pokemon.creer("salameche", 5)
	var bul = Pokemon.creer("bulbizarre", 5)
	var car = Pokemon.creer("carapuce", 5)
	var fl = load("res://scripts/donnees.gd").attaque("flammeche")
	var d_se: int = cb.degats(sal, bul, fl, false, 2.0)
	var d_nt: int = cb.degats(sal, car, fl, false, 0.5)
	ok(d_se > d_nt * 3, "super efficace (%d) >> peu efficace (%d)" % [d_se, d_nt])
	ok(d_se >= 8 and d_se <= 16, "degats plausibles Nv5 : %d" % d_se)
	# combat complet : Salameche Nv5 contre Carapuce Nv5, le joueur spamme la 1re attaque
	var eq = [Pokemon.creer("salameche", 5)]
	var en = [Pokemon.creer("carapuce", 5)]
	var gagne: bool = await cb.combattre(eq, en, "RIVAL")
	ok(en[0].ko() or eq[0].ko(), "le combat se termine par un K.O.")
	ok(gagne == en[0].ko(), "resultat coherent (victoire = %s)" % gagne)
	ok(cb.journal[0].begins_with("RIVAL veut se battre"), "premier message : defi")
	ok(cb.journal.any(func(m): return m.contains("utilise")), "des attaques sont utilisees")
	print("   journal : ", cb.journal.size(), " messages, dernier : ", cb.journal[-1])
	# victoire garantie : Pokemon Nv30 contre Nv3 -> EXP et niveau
	var fort = Pokemon.creer("salameche", 12)
	var faible = Pokemon.creer("carapuce", 3)
	fort.exp = Pokemon.exp_pour_niveau(12)
	cb.journal.clear()
	var g2: bool = await cb.combattre([fort], [faible], "TEST")
	ok(g2 and faible.ko() and fort.exp > Pokemon.exp_pour_niveau(12), "victoire et gain d'EXP (%d)" % fort.exp)
	ok(cb.journal.any(func(m): return m.contains("points d'EXP")), "message d'EXP")
	ok(fort.stades["atk"] == 0, "stades remis a zero apres le combat")
	# defaite : equipe faible
	var g3: bool = await cb.combattre([Pokemon.creer("carapuce", 3)], [Pokemon.creer("salameche", 15)], "TEST")
	ok(not g3, "defaite possible")
	# effet de stat : rugissement baisse l'attaque
	var a = Pokemon.creer("bulbizarre", 5)
	var b = Pokemon.creer("salameche", 5)
	cb.equipe = [a]
	cb.ennemis = [b]
	await cb._effet(a, b, {"stat": "atk", "cible": "adversaire", "stades": -1})
	ok(b.stades["atk"] == -1 and b.stat("atk") < b.stats["atk"], "Rugissement : ATK adverse %d -> %d" % [b.stats["atk"], b.stat("atk")])
	# lutte quand plus de PP
	var c = Pokemon.creer("salameche", 5)
	for x in c.attaques: x["pp"] = 0
	cb.actif_j = c
	var choisi: String = await cb._choisir_attaque()
	ok(choisi == "lutte", "plus de PP -> Lutte")
	print("Erreurs : ", erreurs)
	quit(1 if erreurs > 0 else 0)
