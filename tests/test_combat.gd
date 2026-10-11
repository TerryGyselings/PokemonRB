extends SceneTree
# Ecran de combat en mode "auto" (sans attente) : deroulement complet avec le moteur
const Donnees := preload("res://scripts/donnees.gd")
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
	cb.rng.seed = 42
	# combat de dresseur
	var eq = [Pokemon.creer("salameche", 5)]
	var en = [Pokemon.creer("carapuce", 5)]
	var gagne: bool = await cb.combattre(eq, en, "RIVAL")
	ok(gagne or eq[0].ko(), "le combat se termine (victoire=%s)" % gagne)
	ok(cb.journal[0].begins_with("RIVAL veut se battre"), "premier message : defi")
	ok(cb.journal.any(func(m): return m.contains("utilise")), "des attaques sont utilisees")
	ok(not cb.en_cours and not cb.visible, "ecran ferme apres le combat")
	# victoire facile + EXP
	var fort = Pokemon.creer("salameche", 12)
	var faible = Pokemon.creer("carapuce", 3)
	fort.exp = Pokemon.exp_pour_niveau(12)
	var avant: int = fort.exp
	cb.journal.clear()
	var g2: bool = await cb.combattre([fort], [faible], "TEST")
	ok(g2 and faible.ko() and fort.exp > avant, "victoire et gain d'EXP (%d -> %d)" % [avant, fort.exp])
	ok(cb.journal.any(func(m): return m.contains("points d'EXP")), "message d'EXP")
	ok(fort.stades["atk"] == 0, "stades remis a zero apres le combat")
	# defaite
	var g3: bool = await cb.combattre([Pokemon.creer("carapuce", 3)], [Pokemon.creer("salameche", 15)], "TEST")
	ok(not g3, "defaite possible")
	# combat sauvage : fuite (script_choix : FUITE = index 3)
	var vite = Pokemon.creer("roucool", 30)
	var lent = Pokemon.creer("rattata", 2)
	cb.script_choix = [3]
	var fin: String = await cb.combat_sauvage([vite], lent)
	ok(fin == "fuite", "fuite d'un combat sauvage (%s)" % fin)
	# combat sauvage : victoire
	var gros = Pokemon.creer("salameche", 30)
	var petit = Pokemon.creer("rattata", 2)
	cb.script_choix = []
	cb.journal.clear()
	fin = await cb.combat_sauvage([gros], petit)
	ok(fin == "victoire" and cb.journal[0].begins_with("Un RATTATA sauvage apparait"), "victoire contre un sauvage (%s)" % fin)
	# plus de PP -> Lutte
	var c = Pokemon.creer("salameche", 5)
	for x in c.attaques: x["pp"] = 0
	cb.bat = load("res://scripts/bataille.gd").new()
	cb.bat.demarrer([c], [Pokemon.creer("rattata", 3)], true)
	var choisi: String = await cb._choisir_attaque()
	ok(choisi == "lutte", "plus de PP -> Lutte")
	# remplacement force apres K.O. : le deuxieme prend le relais (auto : premier vivant)
	var a1 = Pokemon.creer("rattata", 3)
	var a2 = Pokemon.creer("salameche", 30)
	a1.pv = 1
	cb.script_choix = []
	fin = await cb.combat_sauvage([a1, a2], Pokemon.creer("onix", 15))
	ok(fin == "victoire" or fin == "defaite", "equipe de deux : le combat va au bout (%s)" % fin)
	# apprentissage avec 4 attaques : on peut refuser (dernier choix)
	var ap = Pokemon.creer("rattata", 10)
	ap.attaques = []
	for id in ["charge", "griffe", "rugissement", "mimi_queue"]:
		ap._ajouter_attaque(id)
	ap.attaques_en_attente = ["morsure"]
	cb.equipe = [ap]
	cb.bat = load("res://scripts/bataille.gd").new()
	cb.bat.demarrer([ap], [Pokemon.creer("rattata", 3)], true)
	var n_att: int = ap.attaques.size()
	cb.script_choix = [4]
	await cb._apprendre(ap, "morsure")
	if n_att >= 4:
		ok(ap.attaques.size() == 4 and not ap.connait("morsure"), "NE PAS APPRENDRE")
		cb.script_choix = [0]
		await cb._apprendre(ap, "morsure")
		ok(ap.connait("morsure") and ap.attaques.size() == 4, "oublier la 1re attaque pour apprendre Morsure")
	else:
		ok(ap.connait("morsure"), "apprend directement avec une place libre")
	print("Erreurs : ", erreurs)
	quit(1 if erreurs > 0 else 0)
