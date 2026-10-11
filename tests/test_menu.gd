extends SceneTree
# Menu en jeu : options selon l'avancement, POKéMON, SAC, fiche du joueur, SAUVEGARDER, QUITTER
var erreurs := 0
var quitte := false
func ok(c: bool, msg: String) -> void:
	print(("OK   " if c else "FAIL ") + msg)
	if not c: erreurs += 1
func textes(n: Node) -> String:
	var s := ""
	if n is Label: s += n.text + "\n"
	for c in n.get_children(): s += textes(c)
	return s
func touche(main, nom: String) -> void:
	main.menu_jeu.appuyer(nom)
	await process_frame
func ouvrir(main) -> void:
	var e := InputEventAction.new()
	e.action = "menu"
	e.pressed = true
	main._unhandled_input(e)
	await process_frame
func _init() -> void:
	load("res://scripts/pokemon.gd").deterministe = true
	var Sauvegarde := load("res://scripts/sauvegarde.gd")
	Sauvegarde.dossier = "user://test_sauvegardes"
	for s in range(1, 4): Sauvegarde.supprimer(s)
	var main = load("res://scene/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.nouvelle_partie(3, "TERRY")
	for c in main.menu_jeu.quitter_demande.get_connections():
		main.menu_jeu.quitter_demande.disconnect(c.callable)
	main.menu_jeu.quitter_demande.connect(func(): quitte = true)
	# sans Pokemon ni Pokedex
	await ouvrir(main)
	var t := textes(main.menu_jeu)
	ok(main.menu_jeu.visible and main.joueur.bloque, "le menu s'ouvre, le joueur est bloque")
	ok(not t.contains("POKéDEX") and not t.contains("POKéMON") and t.contains("SAC") and t.contains("TERRY") and t.contains("SAUVEGARDER") and t.contains("QUITTER"), "avant le starter : ni POKéDEX ni POKéMON")
	await touche(main, "menu")
	ok(not main.menu_jeu.visible and not main.joueur.bloque, "le menu se ferme")
	# sac vide
	await ouvrir(main)
	await touche(main, "action")        # SAC (premiere ligne)
	ok(textes(main.menu_jeu).contains("Le sac est vide"), "sac vide")
	await touche(main, "annuler")
	# avec un Pokemon, le Pokedex et des objets
	main.donner_pokemon("carapuce", 5)
	main.equipe[0].pv = 9
	main.poser_drapeau("pokedex_obtenu")
	main.sac["potion"] = 2
	main.badges.append("cascade")
	await touche(main, "annuler")
	await ouvrir(main)
	t = textes(main.menu_jeu)
	ok(t.contains("POKéDEX") and t.contains("POKéMON"), "avec le starter et le Pokedex : les deux entrees apparaissent")
	await touche(main, "action")        # POKéDEX
	t = textes(main.menu_jeu)
	ok(t.contains("CARAPUCE") and t.contains("007") and t.contains("---") and t.contains("CAPTURES 1"), "pokedex : Carapuce capture, les autres inconnus")
	await touche(main, "bas")
	ok(textes(main.menu_jeu).contains("POKéMON inconnu"), "fiche d'un Pokemon inconnu")
	await touche(main, "annuler")
	await touche(main, "bas")
	await touche(main, "action")        # POKéMON
	ok(textes(main.menu_jeu).contains("CARAPUCE") and textes(main.menu_jeu).contains("PV 9/"), "liste de l'equipe")
	await touche(main, "action")
	t = textes(main.menu_jeu)
	ok(t.contains("ATTAQUE") and t.contains("TYPE  EAU") and t.contains("CHARGE") and t.contains("PP 35/35"), "resume : stats, type, attaques")
	await touche(main, "annuler")
	await touche(main, "annuler")
	await touche(main, "bas")
	await touche(main, "action")        # SAC
	ok(textes(main.menu_jeu).contains("POTION   x2"), "sac : potion x2")
	await touche(main, "action")
	ok(textes(main.menu_jeu).contains("ne peut pas encore"), "objet pas encore utilisable")
	await touche(main, "action")
	await touche(main, "annuler")
	await touche(main, "bas")
	await touche(main, "action")        # fiche joueur
	t = textes(main.menu_jeu)
	ok(t.contains("TERRY") and t.contains("3000 P") and t.contains("1 vus") and t.contains("Cascade") and t.contains("1 dans"), "fiche : nom, argent, pokedex, badge Cascade")
	await touche(main, "annuler")
	# sauvegarde dans l'emplacement 3
	await touche(main, "bas")
	await touche(main, "action")
	ok(textes(main.menu_jeu).contains("emplacement 3"), "demande de sauvegarde")
	await touche(main, "action")        # OUI
	ok(Sauvegarde.existe(3) and textes(main.menu_jeu).contains("a sauvegardé"), "partie sauvegardee dans l'emplacement 3")
	await touche(main, "action")
	ok(Sauvegarde.lire(3)["equipe"][0]["pv"] == 9, "la sauvegarde contient l'equipe")
	# quitter : NON puis OUI
	await touche(main, "bas")
	await touche(main, "action")
	await touche(main, "bas")
	await touche(main, "action")        # NON
	ok(not quitte and main.menu_jeu.visible, "QUITTER puis NON : on reste dans le jeu")
	await touche(main, "action")
	await touche(main, "action")        # OUI
	await process_frame
	ok(quitte and not main.menu_jeu.visible, "QUITTER puis OUI : demande de fermeture du jeu")
	# le menu ne s'ouvre pas pendant un evenement
	main.evenement_en_cours = true
	main.joueur.bloque = true
	await ouvrir(main)
	ok(not main.menu_jeu.visible, "menu refuse pendant un evenement")
	for s in range(1, 4): Sauvegarde.supprimer(s)
	print("=== ERREURS : ", erreurs)
	quit(1 if erreurs > 0 else 0)
