extends SceneTree
# Souris + clavier combines : ecran titre, menu en jeu, dialogues, question OUI/NON et combat
var erreurs := 0
func ok(c: bool, msg: String) -> void:
	print(("OK   " if c else "FAIL ") + msg)
	if not c: erreurs += 1
func textes(n: Node) -> String:
	var s := ""
	if n is Label: s += n.text + "\n"
	for c in n.get_children(): s += textes(c)
	return s
func bouge(cible, pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	cible._input(e)
	await process_frame
func clic(cible, pos: Vector2, bouton := MOUSE_BUTTON_LEFT) -> void:
	var e := InputEventMouseButton.new()
	e.position = pos
	e.button_index = bouton
	e.pressed = true
	cible._input(e)
	await process_frame
func _init() -> void:
	load("res://scripts/pokemon.gd").deterministe = true
	var Sauvegarde := load("res://scripts/sauvegarde.gd")
	Sauvegarde.dossier = "user://test_sauvegardes"
	for s in range(1, 4): Sauvegarde.supprimer(s)
	# ---------- ecran titre ----------
	var main = load("res://scene/main.tscn").instantiate()
	main.avec_titre = true
	root.add_child(main)
	await create_timer(0.3).timeout
	var t = main.titre
	await clic(t, Vector2(240, 160))                       # n'importe ou : "appuie sur un bouton"
	ok(textes(t).contains("NOUVELLE PARTIE"), "titre : un clic passe a l'ecran du menu")
	await bouge(t, t.centre_ligne(1))
	ok(textes(t).contains("> NOUVELLE PARTIE"), "survol : le curseur suit la souris")
	await clic(t, t.centre_ligne(0))
	ok(not textes(t).contains("EMPLACEMENT"), "CONTINUER grise (pas de sauvegarde) : le clic est ignore")
	await clic(t, t.centre_ligne(1))
	ok(textes(t).contains("EMPLACEMENT 1"), "clic sur NOUVELLE PARTIE : liste des emplacements")
	await clic(t, Vector2(5, 5))
	ok(textes(t).contains("EMPLACEMENT 1"), "clic hors des lignes : rien ne se passe")
	await clic(t, Vector2(5, 5), MOUSE_BUTTON_RIGHT)
	ok(textes(t).contains("NOUVELLE PARTIE") and not textes(t).contains("EMPLACEMENT 1"), "clic droit : retour au menu")
	await clic(t, t.centre_ligne(1))
	await bouge(t, t.centre_ligne(2))
	t.appuyer("haut")                                      # clavier apres la souris
	await process_frame
	await clic(t, t.centre_ligne(1))                      # emplacement 2
	ok(textes(t).contains("COMMENT T'APPELLES-TU"), "clic sur l'emplacement 2 : saisie du nom")
	for c in "ASH":
		var e := InputEventKey.new()
		e.pressed = true
		e.unicode = c.unicode_at(0)
		e.keycode = c.unicode_at(0)
		t.clavier.emit(e)
		await process_frame
	var e := InputEventKey.new()
	e.pressed = true
	e.keycode = KEY_ENTER
	t.clavier.emit(e)
	await process_frame
	ok(main.partie_en_cours and main.nom_joueur == "ASH" and main.slot_actuel == 2, "partie lancee a la souris + clavier (%s, slot %d)" % [main.nom_joueur, main.slot_actuel])
	# ---------- menu en jeu ----------
	var ev := InputEventAction.new()
	ev.action = "menu"
	ev.pressed = true
	main._unhandled_input(ev)
	await process_frame
	var m = main.menu_jeu
	await bouge(m, m.centre_ligne(1))
	ok(textes(m).contains("> ASH"), "menu : survol de la 2e ligne")
	await clic(m, m.centre_ligne(0), MOUSE_BUTTON_WHEEL_DOWN)
	ok(textes(m).contains("> SAUVEGARDER"), "molette : le curseur descend (clavier et souris combines)")
	await clic(m, m.centre_ligne(1))
	ok(textes(m).contains("ARGENT"), "menu : clic sur le nom ouvre la fiche du joueur")
	await clic(m, Vector2(100, 100))
	ok(not textes(m).contains("BADGES") and textes(m).contains("SAUVEGARDER"), "un clic ferme la fiche et revient au menu")
	await clic(m, Vector2(100, 100), MOUSE_BUTTON_RIGHT)
	ok(not m.visible and not main.joueur.bloque, "clic droit : le menu se ferme")
	# ---------- dialogue ----------
	main.dire(["page un", "page deux"])
	await clic(main, Vector2(240, 280))
	ok(main.texte.text == "page deux", "un clic fait avancer le dialogue")
	await clic(main, Vector2(240, 280))
	ok(not main.boite.visible, "un clic ferme le dialogue")
	# ---------- question OUI / NON dans le monde ----------
	var res := []
	var poser := func():
		res.append(await main.oui_non("Question ?"))
	poser.call()
	await process_frame
	await bouge(main, main.rect_choix(1).get_center())
	ok(main._choix_index == 1, "survol de NON")
	await clic(main, main.rect_choix(1).get_center())
	ok(res == [false] and not main.boite.visible, "clic sur NON : reponse non")
	poser.call()
	await process_frame
	await clic(main, main.rect_choix(0).get_center())
	ok(res == [false, true], "clic sur OUI : reponse oui")
	# ---------- combat ----------
	main.nouvelle_partie(1, "ASH")
	main.donner_pokemon("salameche", 5)
	var en = [load("res://scripts/pokemon.gd").creer("carapuce", 5)]
	var cb = main.combat
	cb.combattre(main.equipe, en, "REGIS")
	await process_frame
	for i in 3:
		await create_timer(0.35).timeout                  # (pause d'animation entre deux messages)
		await clic(cb, Vector2(240, 280))                 # messages d'introduction
	await create_timer(0.4).timeout
	ok(textes(cb).contains("Que doit faire"), "combat : 3 clics font avancer les messages jusqu'au menu")
	await bouge(cb, cb.centre_ligne(3))
	ok(textes(cb).contains("> FUITE"), "combat : survol de FUITE")
	await clic(cb, cb.centre_ligne(3))
	ok(textes(cb).contains("On ne s'enfuit pas"), "combat : clic sur FUITE")
	await clic(cb, Vector2(240, 280))
	await clic(cb, cb.centre_ligne(0))                    # COMBAT
	ok(textes(cb).contains("Griffe") and textes(cb).contains("Rugissement"), "combat : la liste des attaques s'affiche")
	await clic(cb, Vector2(5, 5), MOUSE_BUTTON_RIGHT)    # clic droit : retour au menu
	ok(textes(cb).contains("Que doit faire"), "combat : clic droit revient au menu principal")
	await clic(cb, cb.centre_ligne(0))
	await bouge(cb, cb.centre_ligne(1))
	await clic(cb, cb.centre_ligne(1))                    # Rugissement
	await create_timer(0.3).timeout
	ok(cb.journal.any(func(x): return x.contains("utilise RUGISSEMENT")), "combat : clic sur la 2e attaque (%s)" % [cb.journal[-1]])
	for s in range(1, 4): Sauvegarde.supprimer(s)
	print("=== ERREURS : ", erreurs)
	quit(1 if erreurs > 0 else 0)
