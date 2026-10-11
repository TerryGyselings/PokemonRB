extends SceneTree
# Capture (formule, balles, combat), stockage dans l'equipe / les boites du PC, ecran du PC, sauvegarde
const Donnees := preload("res://scripts/donnees.gd")
const Pokemon := preload("res://scripts/pokemon.gd")
const Bataille := preload("res://scripts/bataille.gd")
var erreurs := 0
func ok(c: bool, msg: String) -> void:
	print(("OK   " if c else "FAIL ") + msg)
	if not c: erreurs += 1
func attendre(s := 0.15) -> void:
	await create_timer(s).timeout
func _init() -> void:
	Pokemon.deterministe = true
	# ---------- formule ----------
	var b = Bataille.new(3)
	var rat = Pokemon.creer("rattata", 10)
	b.demarrer([Pokemon.creer("salameche", 10)], [rat], true)
	var a_plein: float = b.facteur_capture(rat, 1.0)
	ok(absf(a_plein - 255.0 * (3.0 * rat.stats["pv"] - 2.0 * rat.pv) / (3.0 * rat.stats["pv"])) < 0.01 and absf(a_plein - 85.0) < 0.01, "Rattata PV pleins, POKe BALL : a = 85 (%f)" % a_plein)
	rat.pv = 1
	ok(b.facteur_capture(rat, 1.0) > 200.0, "PV a 1 : facteur eleve (%f)" % b.facteur_capture(rat, 1.0))
	rat.pv = rat.stats["pv"]
	var base: float = b.facteur_capture(rat, 1.0)
	rat.statut = "sommeil"
	ok(absf(b.facteur_capture(rat, 1.0) - base * 2.5) < 0.01, "sommeil x2.5")
	rat.statut = "paralysie"
	ok(absf(b.facteur_capture(rat, 1.0) - base * 1.5) < 0.01, "paralysie x1.5")
	rat.statut = ""
	ok(b.facteur_capture(rat, 2.0) > b.facteur_capture(rat, 1.5) and b.facteur_capture(rat, 1.5) > base, "Hyper > Super > Poke Ball")
	# taux observes
	var n := 4000
	var ok_rat := 0
	var ok_onix := 0
	var ok_master := 0
	var onix = Pokemon.creer("onix", 10)
	for i in n:
		if b.tenter_capture(rat, 1.0)["capture"]: ok_rat += 1
		if b.tenter_capture(onix, 1.0)["capture"]: ok_onix += 1
		if b.tenter_capture(onix, 255.0)["capture"]: ok_master += 1
	var p_rat := float(ok_rat) / n
	var p_onix := float(ok_onix) / n
	ok(p_rat > 0.39 and p_rat < 0.49, "Rattata PV pleins ~44 %% de capture (%.3f)" % p_rat)
	ok(p_onix > 0.08 and p_onix < 0.16, "Onix PV pleins ~12 %% (%.3f)" % p_onix)
	ok(ok_master == n, "Master Ball : toujours")
	# ---------- dans le moteur ----------
	var j = Pokemon.creer("salameche", 10)
	var cible = Pokemon.creer("rattata", 5)
	var bb = Bataille.new(1)
	bb.demarrer([j], [cible], true)
	bb.vider_evenements()
	bb.tour({"t": "balle", "id": "master_ball"})
	var evs: Array = bb.vider_evenements()
	ok(bb.fin == "capture" and bb.capture == cible and cible.balle == "master_ball", "capture au tour : fin=capture")
	ok(evs.any(func(e): return e["t"] == "balle" and e["capture"]) and evs.any(func(e): return e["t"] == "msg" and "est capture" in e["texte"]), "evenements : balle + message")
	ok(j.exp > j.exp_seuil(10), "EXP gagnee a la capture")
	# balle ratee : le combat continue
	var fort = Pokemon.creer("onix", 30)
	bb = Bataille.new(2)
	bb.demarrer([Pokemon.creer("salameche", 30)], [fort], true)
	var rate := false
	for i in 30:
		bb.vider_evenements()
		bb.tour({"t": "balle", "id": "poke_ball"})
		if bb.fin == "": rate = true; break
		bb.fin = ""   # pour retenter
		fort.balle = ""
	ok(rate, "une balle peut rater (le combat continue)")
	# ---------- jeu : equipe / PC ----------
	var main = load("res://scene/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.nouvelle_partie(1, "ASH")
	ok(main.boites.size() == 14 and main.boites[0].size() == 30, "14 boites de 30")
	main.donner_pokemon("salameche", 8)
	var recu: Dictionary = main.recevoir_pokemon(Pokemon.creer("rattata", 3))
	ok(recu["ou"] == "equipe" and main.equipe.size() == 2 and main.captures.has("rattata"), "equipe non pleine : le Pokemon rejoint l'equipe + Pokedex")
	for i in 4: main.recevoir_pokemon(Pokemon.creer("roucool", 3))
	ok(main.equipe.size() == 6, "equipe pleine (6)")
	var shiny = Pokemon.creer("pikachu", 5, {"shiny": true})
	recu = main.recevoir_pokemon(shiny)
	ok(recu["ou"] == "boite" and recu["boite"] == 0 and main.boites[0][0] == shiny, "equipe pleine : Pokemon envoye dans la boite 1")
	ok(main.place_libre_boite() == Vector2i(0, 1), "prochaine place libre")
	main.boites[0].fill(shiny)
	ok(main.place_libre_boite() == Vector2i(1, 0), "boite 1 pleine : on passe a la 2")
	main.boites[0].fill(null)
	main.boites[0][0] = shiny
	# sauvegarde
	var d: Dictionary = JSON.parse_string(JSON.stringify(main.exporter()))
	main.nouvelle_partie(2, "X")
	ok(main.boites[0][0] == null, "nouvelle partie : boites vides")
	main.importer(d, 1)
	ok(main.boites[0][0] != null and main.boites[0][0].espece_id == "pikachu" and main.boites[0][0].shiny and main.equipe.size() == 6, "sauvegarde / chargement des boites (shiny conserve)")
	# ---------- combat complet avec une balle ----------
	main.combat.auto = true
	main.sac = {"master_ball": 1}
	main.boites[0].fill(null)
	var sauvage = Pokemon.creer("rattata", 4)
	main.combat.script_choix = [1, 0]   # SAC, 1er objet
	var fin: String = await main.combat.combat_sauvage(main.equipe, sauvage)
	ok(fin == "capture", "combat : SAC > MASTER BALL > capture (%s)" % fin)
	ok(main.sac.get("master_ball", 0) == 0, "la balle est consommee")
	ok(main.boites[0][0] != null and main.boites[0][0].espece_id == "rattata" and main.boites[0][0].dresseur_origine == "ASH", "capture : envoye dans la boite 1 (equipe pleine)")
	ok(main.combat.journal.any(func(m): return "BOITE 1" in m), "message 'envoye dans la BOITE 1'")
	# dresseur : interdit
	main.sac = {"poke_ball": 3}
	main.combat.script_choix = [1, 0, 0]
	main.combat.journal.clear()
	var gagne: bool = await main.combat.combattre(main.equipe, [Pokemon.creer("rattata", 2)], "RIVAL")
	ok(main.combat.journal.any(func(m): return "voler" in m) and main.sac["poke_ball"] == 3, "on ne vole pas le Pokemon d'un dresseur (balle non consommee)")
	# ---------- ecran du PC ----------
	main.equipe.resize(2)
	main.boites[0].fill(null)
	main.boites[0][0] = Pokemon.creer("pikachu", 5)
	main.boites[0][1] = Pokemon.creer("roucool", 5)
	main.pc.ouvrir()
	await attendre()
	ok(main.pc.visible and main.pc.actif and main.pc._curseur == 6, "le PC s'ouvre sur la boite 1")
	main.pc.appuyer("gauche")
	await attendre()
	ok(main.pc._curseur == 0, "gauche : curseur sur l'equipe")
	main.pc.appuyer("action")      # menu
	await attendre()
	main.pc.appuyer("action")      # DEPOSER
	await attendre(0.3)
	main.pc.appuyer("action")      # ferme le message
	await attendre()
	ok(main.equipe.size() == 1 and main.boites[0][2] != null and main.boites[0][2].espece_id == "salameche", "DEPOSER : l'equipe passe a 1, Salameche en boite (%d)" % main.equipe.size())
	main.pc.appuyer("action")      # menu sur le dernier POKEMON
	await attendre()
	main.pc.appuyer("action")      # DEPOSER (refuse)
	await attendre(0.3)
	main.pc.appuyer("action")
	await attendre()
	ok(main.equipe.size() == 1, "on ne depose pas son dernier POKEMON")
	main.pc.appuyer("droite")
	await attendre()
	ok(main.pc._curseur == 6, "droite : curseur dans la boite")
	main.pc.appuyer("action")      # menu Pikachu
	await attendre()
	main.pc.appuyer("action")      # RETIRER
	await attendre(0.3)
	main.pc.appuyer("action")
	await attendre()
	ok(main.equipe.size() == 2 and main.equipe[1].espece_id == "pikachu" and main.boites[0][0] == null, "RETIRER : Pikachu rejoint l'equipe")
	main.pc.appuyer("haut")
	await attendre()
	ok(main.pc._curseur == 36, "haut depuis la 1re ligne : curseur sur l'en-tete (%d)" % main.pc._curseur)
	main.pc.appuyer("droite")
	main.pc.appuyer("action")
	await attendre()
	ok(main.pc._boite_courante == 1, "fleche > : boite 2")
	main.pc.appuyer("annuler")
	await attendre(0.3)
	ok(not main.pc.visible and not main.pc.actif, "le PC se ferme")
	# interaction de l'ordinateur du Centre Pokemon
	main.charger_carte("centre_pokemon_jadielle")
	var it: Dictionary = main.carte.interaction(Vector2i(12, 0))
	ok(it.get("evenement", "") == "pc_ouvrir", "l'ordinateur du Centre ouvre le PC")
	print("ERREURS : ", erreurs)
	quit(1 if erreurs > 0 else 0)
